#Requires AutoHotkey v2.0
#SingleInstance Force

#include UIA.ahk

A_MaxHotkeysPerInterval := 200

; ============================================================
; EXPLORER SHELL NAVIGATION V3
;
; NORMAL WHEEL:
;   Wheel Down -> next file
;   Wheel Up   -> previous file
;
; IMPORTANT:
;   The mouse position determines the STARTING file only.
;
;   After navigation begins, the script remembers the actual
;   Shell folder index and continues from that item.
;
; This prevents Explorer scrolling in Details view from causing
; the navigation to jump back to another visible row.
;
; CURSOR:
;   After every selection, the mouse is moved to the selected
;   file using SetCursorPos().
;
; WRAP-AROUND:
;   Last file + Wheel Down -> first file
;   First file + Wheel Up   -> last file
;
; RIGHT CLICK + WHEEL:
;   Explorer scrolls normally.
;   No blue drag-selection.
;   No context menu after scrolling.
;
; IMPORTANT:
;   The script only intercepts mouse buttons/wheel inside
;   File Explorer. Other applications are left untouched.
; ============================================================


; ============================================================
; GLOBAL STATE
; ============================================================

global PendingMoves := 0
global MaxPendingMoves := 3
global ProcessingMove := false


; ============================================================
; PERSISTENT NAVIGATION STATE
; ============================================================

global NavigationActive := false
global NavigationIndex := -1
global NavigationCount := 0

global NavigationShellView := 0
global NavigationFolderItems := 0

global NavigationFolderPath := ""


; ============================================================
; MOUSE STATE
; ============================================================

global LastScriptX := ""
global LastScriptY := ""


; ============================================================
; RIGHT CLICK STATE
; ============================================================

global RightButtonHeld := false
global RightScrollUsed := false

CoordMode "Mouse", "Screen"


; ============================================================
; RIGHT MOUSE BUTTON
;
; IMPORTANT:
; These hotkeys exist ONLY while File Explorer is active.
;
; Other applications never enter these handlers.
; ============================================================

#HotIf IsExplorerWindow()

RButton::
{
    global RightButtonHeld
    global RightScrollUsed

    RightButtonHeld := true
    RightScrollUsed := false

    ; Stop custom navigation.
    ResetNavigation()
}

RButton Up::
{
    global RightButtonHeld
    global RightScrollUsed

    ; Plain right click:
    ; perform normal Explorer right-click.
    if !RightScrollUsed
        Send "{RButton}"

    RightButtonHeld := false
    RightScrollUsed := false
}

#HotIf


; ============================================================
; RIGHT CLICK + WHEEL
;
; Only active inside File Explorer.
;
; Right click + wheel:
;   -> normal Explorer scrolling
;   -> no custom file selection
;   -> no context menu after scrolling
; ============================================================

#HotIf RightButtonHeld && IsExplorerWindow()

WheelDown::
{
    global RightScrollUsed

    RightScrollUsed := true

    ; Pass normal wheel event to Explorer.
    Send "{WheelDown}"
}

WheelUp::
{
    global RightScrollUsed

    RightScrollUsed := true

    ; Pass normal wheel event to Explorer.
    Send "{WheelUp}"
}

#HotIf


; ============================================================
; NORMAL CUSTOM WHEEL
;
; Only active over the main File Explorer file list.
; ============================================================

#HotIf IsCustomWheelArea()

WheelDown::
{
    global PendingMoves
    global MaxPendingMoves

    if PendingMoves < MaxPendingMoves
        PendingMoves++
}

WheelUp::
{
    global PendingMoves
    global MaxPendingMoves

    if PendingMoves > -MaxPendingMoves
        PendingMoves--
}

#HotIf


; ============================================================
; WORKER
;
; Keep the 10 ms interval from the known-good version.
; ============================================================

SetTimer ProcessWheelQueue, 10


ProcessWheelQueue()
{
    global PendingMoves
    global ProcessingMove

    global NavigationActive
    global NavigationIndex
    global NavigationCount
    global NavigationShellView
    global NavigationFolderItems
    global NavigationFolderPath

    global LastScriptX
    global LastScriptY


    ; --------------------------------------------------------
    ; Don't process another movement while one is running.
    ; --------------------------------------------------------

    if ProcessingMove
        return

    if PendingMoves = 0
        return


    ; --------------------------------------------------------
    ; Right-click always wins.
    ; --------------------------------------------------------

    if GetKeyState("RButton", "P")
    {
        PendingMoves := 0
        ResetNavigation()
        return
    }


    ; --------------------------------------------------------
    ; Explorer must still be active.
    ; --------------------------------------------------------

    if !IsExplorerWindow()
    {
        PendingMoves := 0
        ResetNavigation()
        return
    }


    ; ========================================================
    ; CHECK FOR MANUAL MOUSE MOVEMENT
    ; ========================================================

    MouseGetPos &currentX, &currentY

    if (LastScriptX != "" && LastScriptY != "")
    {
        if (Abs(currentX - LastScriptX) > 5
            || Abs(currentY - LastScriptY) > 5)
        {
            PendingMoves := 0

            ResetNavigation()

            LastScriptX := currentX
            LastScriptY := currentY

            return
        }
    }


    ProcessingMove := true


    try
    {
        ; ====================================================
        ; TAKE ONE MOVEMENT FROM QUEUE
        ; ====================================================

        if PendingMoves > 0
        {
            direction := "Down"
            PendingMoves--
        }
        else
        {
            direction := "Up"
            PendingMoves++
        }


        ; ====================================================
        ; FIRST NAVIGATION MOVEMENT
        ;
        ; The mouse establishes the starting file ONLY HERE.
        ; ====================================================

        if !NavigationActive
        {
            MouseGetPos &mouseX, &mouseY

            referenceItem := FindReferenceItem(
                mouseX,
                mouseY,
                direction
            )


            if !referenceItem
                return


            ; ------------------------------------------------
            ; Get the active Explorer Shell view.
            ; ------------------------------------------------

            shellView := GetActiveExplorerShellView()

            if !shellView
            {
                ToolTip "Could not access Explorer folder view"
                SetTimer () => ToolTip(), -1200
                return
            }


            ; ------------------------------------------------
            ; Get the COMPLETE folder collection.
            ; ------------------------------------------------

            folderItems := shellView.Folder.Items()

            itemCount := folderItems.Count

            if itemCount = 0
                return


            ; ------------------------------------------------
            ; Identify the starting Shell item.
            ; ------------------------------------------------

            referencePath := GetShellItemPath(referenceItem)

            if referencePath = ""
            {
                ; UIA may not expose the Shell path directly.
                ; Fall back to the item's name.
                referenceName := referenceItem.Name

                referenceIndex := FindShellItemIndexByName(
                    folderItems,
                    referenceName
                )
            }
            else
            {
                referenceIndex := FindShellItemIndexByPath(
                    folderItems,
                    referencePath
                )
            }


            if referenceIndex < 0
            {
                ToolTip "Could not locate starting file"
                SetTimer () => ToolTip(), -1200
                return
            }


            ; ------------------------------------------------
            ; Store the navigation state.
            ; ------------------------------------------------

            NavigationShellView := shellView
            NavigationFolderItems := folderItems
            NavigationCount := itemCount
            NavigationFolderPath := GetCurrentFolderPath(shellView)

            NavigationIndex := referenceIndex
            NavigationActive := true


            ; ------------------------------------------------
            ; First movement.
            ; ------------------------------------------------

            NavigationIndex := GetNextIndex(
                NavigationIndex,
                direction,
                NavigationCount
            )
        }
        else
        {
            ; =================================================
            ; SUBSEQUENT MOVEMENTS
            ;
            ; DO NOT LOOK AT THE MOUSE.
            ; =================================================

            try
            {
                NavigationCount :=
                    NavigationShellView.Folder.Items().Count

                NavigationFolderItems :=
                    NavigationShellView.Folder.Items()
            }
            catch
            {
                ResetNavigation()
                return
            }


            if NavigationCount = 0
            {
                ResetNavigation()
                return
            }


            ; Make sure index remains valid.

            if NavigationIndex >= NavigationCount
                NavigationIndex := NavigationCount - 1

            if NavigationIndex < 0
                NavigationIndex := 0


            ; Move to next/previous item.

            NavigationIndex := GetNextIndex(
                NavigationIndex,
                direction,
                NavigationCount
            )
        }


        ; ====================================================
        ; GET TARGET SHELL ITEM
        ; ====================================================

        targetShellItem :=
            NavigationFolderItems.Item(NavigationIndex)


        if !targetShellItem
            return


        ; ====================================================
        ; SELECT TARGET USING EXPLORER'S OWN SHELL VIEW
        ;
        ; 1  = select
        ; 4  = deselect other items
        ; 8  = ensure visible
        ; 16 = focus
        ;
        ; 29 = all of the above.
        ; ====================================================

        NavigationShellView.SelectItem(
            targetShellItem,
            29
        )


        ; ----------------------------------------------------
        ; Small delay for Explorer's UI to update.
        ; ----------------------------------------------------

        Sleep 15


        ; ====================================================
        ; FIND THE NEWLY SELECTED ITEM
        ; ====================================================

        newPointFound := false


        try
        {
            newItem := UIA.GetFocusedElement()


            if newItem
            {
                try
                {
                    if newItem.Type = 50007
                    {
                        clickablePoint :=
                            newItem.GetClickablePoint()

                        if IsObject(clickablePoint)
                        {
                            newPoint := clickablePoint
                            newPointFound := true
                        }
                    }
                }
                catch
                {
                    ; Clickable point unavailable.
                }


                ; ------------------------------------------------
                ; Rectangle fallback.
                ; ------------------------------------------------

                if !newPointFound
                {
                    try
                    {
                        rect := newItem.BoundingRectangle

                        if (rect.r > rect.l
                            && rect.b > rect.t)
                        {
                            newPoint := {
                                x: Round(
                                    (rect.l + rect.r) / 2
                                ),
                                y: Round(
                                    (rect.t + rect.b) / 2
                                )
                            }

                            newPointFound := true
                        }
                    }
                    catch
                    {
                    }
                }
            }
        }
        catch
        {
        }


        ; ====================================================
        ; MOVE MOUSE TO SELECTED FILE
        ;
        ; IMPORTANT:
        ; Keep SetCursorPos().
        ; ====================================================

        if newPointFound
        {
            DllCall(
                "SetCursorPos",
                "Int",
                newPoint.x,
                "Int",
                newPoint.y
            )

            ; Remember where OUR script placed the cursor.

            LastScriptX := newPoint.x
            LastScriptY := newPoint.y
        }
        else
        {
            ToolTip "Selected file, but could not locate cursor point"
            SetTimer () => ToolTip(), -1200
        }
    }
    catch as err
    {
        PendingMoves := 0

        ToolTip "ERROR: " err.Message
        SetTimer () => ToolTip(), -1800

        ResetNavigation()
    }
    finally
    {
        ProcessingMove := false
    }
}


; ============================================================
; GET NEXT INDEX
;
; Handles normal navigation AND wrap-around.
; ============================================================

GetNextIndex(currentIndex, direction, itemCount)
{
    if itemCount <= 0
        return -1


    if direction = "Down"
    {
        nextIndex := currentIndex + 1

        if nextIndex >= itemCount
            nextIndex := 0

        return nextIndex
    }


    ; Wheel Up

    nextIndex := currentIndex - 1

    if nextIndex < 0
        nextIndex := itemCount - 1

    return nextIndex
}


; ============================================================
; GET ACTIVE EXPLORER SHELL VIEW
; ============================================================

GetActiveExplorerShellView()
{
    activeHwnd := WinExist("A")

    shell := ComObject("Shell.Application")


    for explorerWindow in shell.Windows
    {
        try
        {
            if explorerWindow.HWND = activeHwnd
                return explorerWindow.Document
        }
        catch
        {
            continue
        }
    }


    return 0
}


; ============================================================
; GET CURRENT FOLDER PATH
; ============================================================

GetCurrentFolderPath(shellView)
{
    try
    {
        return shellView.Folder.Self.Path
    }
    catch
    {
        return ""
    }
}


; ============================================================
; FIND SHELL ITEM BY PATH
; ============================================================

FindShellItemIndexByPath(folderItems, targetPath)
{
    try
    {
        Loop folderItems.Count
        {
            index := A_Index - 1

            try
            {
                item := folderItems.Item(index)

                if item.Path = targetPath
                    return index
            }
            catch
            {
                continue
            }
        }
    }
    catch
    {
    }


    return -1
}


; ============================================================
; FIND SHELL ITEM BY NAME
; ============================================================

FindShellItemIndexByName(folderItems, targetName)
{
    try
    {
        Loop folderItems.Count
        {
            index := A_Index - 1

            try
            {
                item := folderItems.Item(index)

                if item.Name = targetName
                    return index
            }
            catch
            {
                continue
            }
        }
    }
    catch
    {
    }


    return -1
}


; ============================================================
; GET SHELL PATH FROM UIA ITEM
; ============================================================

GetShellItemPath(uiaItem)
{
    try
    {
        ; UIA ListItems generally don't expose the filesystem
        ; path directly, so this is intentionally best-effort.

        return ""
    }
    catch
    {
        return ""
    }
}


; ============================================================
; FIND FILE UNDER CURSOR / HANDLE EMPTY SPACE
;
; THIS FUNCTION IS USED ONLY WHEN NAVIGATION STARTS.
;
; Once NavigationActive becomes true, this function is NOT
; called again until the user manually moves the mouse.
; ============================================================

FindReferenceItem(mouseX, mouseY, direction)
{
    ; --------------------------------------------------------
    ; First attempt:
    ; exact UIA element under cursor.
    ; --------------------------------------------------------

    try
    {
        hoverElement := UIA.ElementFromPoint(
            mouseX,
            mouseY
        )


        walker := UIA.CreateTreeWalker(
            {Type: "ListItem"}
        )


        hoverItem := walker.NormalizeElement(
            hoverElement
        )


        if hoverItem
            return hoverItem
    }
    catch
    {
        ; Fall through to rectangle search.
    }


    ; --------------------------------------------------------
    ; Determine Explorer control underneath cursor.
    ; --------------------------------------------------------

    MouseGetPos , , , &control


    if !InStr(control, "DirectUIHWND")
        return 0


    ; --------------------------------------------------------
    ; Convert Explorer control to UIA element.
    ; --------------------------------------------------------

    try
    {
        controlHwnd := ControlGetHwnd(
            control,
            "A"
        )

        mainElement :=
            UIA.ElementFromHandle(controlHwnd)

        items :=
            mainElement.FindElements(
                {Type: "ListItem"}
            )
    }
    catch
    {
        return 0
    }


    if items.Length = 0
        return 0


    ; --------------------------------------------------------
    ; Find nearest item.
    ; --------------------------------------------------------

    bestBelow := 0
    bestBelowTop := 0

    bestAbove := 0
    bestAboveBottom := 0

    firstItem := 0
    firstTop := 0

    lastItem := 0
    lastBottom := 0


    for item in items
    {
        try
        {
            rect := item.BoundingRectangle


            ; ------------------------------------------------
            ; Exact rectangle hit.
            ; ------------------------------------------------

            if (mouseX >= rect.l
                && mouseX <= rect.r
                && mouseY >= rect.t
                && mouseY <= rect.b)
            {
                return item
            }


            ; ------------------------------------------------
            ; First visible item.
            ; ------------------------------------------------

            if !firstItem || rect.t < firstTop
            {
                firstItem := item
                firstTop := rect.t
            }


            ; ------------------------------------------------
            ; Last visible item.
            ; ------------------------------------------------

            if !lastItem || rect.b > lastBottom
            {
                lastItem := item
                lastBottom := rect.b
            }


            ; ------------------------------------------------
            ; Item below cursor.
            ; ------------------------------------------------

            if rect.t >= mouseY
            {
                if !bestBelow
                    || rect.t < bestBelowTop
                {
                    bestBelow := item
                    bestBelowTop := rect.t
                }
            }


            ; ------------------------------------------------
            ; Item above cursor.
            ; ------------------------------------------------

            if rect.b <= mouseY
            {
                if !bestAbove
                    || rect.b > bestAboveBottom
                {
                    bestAbove := item
                    bestAboveBottom := rect.b
                }
            }
        }
        catch
        {
            continue
        }
    }


    ; --------------------------------------------------------
    ; Choose starting item.
    ; --------------------------------------------------------

    if direction = "Down"
    {
        if bestBelow
            return bestBelow

        ; Cursor below visible files.
        return lastItem
    }


    if bestAbove
        return bestAbove


    ; Cursor above visible files.
    return firstItem
}


; ============================================================
; RESET NAVIGATION
;
; Called when:
;   - user manually moves mouse
;   - right-click starts
;   - Explorer loses focus
;   - an error occurs
; ============================================================

ResetNavigation()
{
    global NavigationActive
    global NavigationIndex
    global NavigationCount
    global NavigationShellView
    global NavigationFolderItems
    global NavigationFolderPath

    global LastScriptX
    global LastScriptY


    NavigationActive := false
    NavigationIndex := -1
    NavigationCount := 0

    NavigationShellView := 0
    NavigationFolderItems := 0

    NavigationFolderPath := ""

    LastScriptX := ""
    LastScriptY := ""
}


; ============================================================
; CUSTOM WHEEL AREA
; ============================================================

IsCustomWheelArea()
{
    if !IsExplorerWindow()
        return false


    if GetKeyState("RButton", "P")
        return false


    MouseGetPos , , , &control


    if InStr(control, "DirectUIHWND")
        return true


    return false
}


; ============================================================
; EXPLORER WINDOW CHECK
; ============================================================

IsExplorerWindow()
{
    return WinActive(
        "ahk_class CabinetWClass"
    )
    || WinActive(
        "ahk_class ExploreWClass"
    )
}