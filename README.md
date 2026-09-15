# Explorer Scroll Navigation

A Windows 11 AutoHotkey v2 utility that turns the mouse wheel into file-selection navigation inside File Explorer.

Instead of scrolling through a folder and then moving the mouse to select a file, you can simply hover over the file area and use the mouse wheel to move the selection.

The cursor automatically follows the selected file, allowing it to be opened immediately with a double-click.

## Features

- **Mouse wheel file navigation**
  - Wheel Down → select the next file
  - Wheel Up → select the previous file

- **Mouse-position based starting point**
  - The first wheel movement determines the starting file based on the cursor position.
  - If the cursor is between files, the navigation starts from the appropriate nearby item.

- **Persistent navigation**
  - After navigation starts, the script maintains its position in the folder instead of repeatedly determining the item underneath the cursor.

- **Works beyond the visible area**
  - Navigation can continue through files that are not currently visible in the Explorer window.

- **Wrap-around navigation**
  - Moving down from the last item returns to the first.
  - Moving up from the first item returns to the last.

- **Automatic cursor positioning**
  - The cursor follows the currently selected file.
  - This makes it possible to immediately double-click the selected item.

- **Right-click compatibility**
  - Right-click + mouse wheel retains normal Explorer scrolling.
  - Right-click without scrolling opens the normal Explorer context menu.

- **Explorer-only behavior**
  - The custom wheel behavior is limited to the main File Explorer file area.
  - The navigation pane and other applications continue to use normal mouse-wheel behavior.

- **Rapid scrolling support**
  - Wheel input is processed through a small queue to prevent excessive input from interfering with Explorer.

## Requirements

- Windows 10/11
- [AutoHotkey v2](https://www.autohotkey.com/)
- UI Automation library used by the script

The script was developed and tested primarily with Windows 11 File Explorer.

## Installation

### 1. Install AutoHotkey v2

Download and install AutoHotkey v2 from the official website:

https://www.autohotkey.com/

Make sure you are using **AutoHotkey v2**, not v1.

### 2. Install the UI Automation library

This project uses the `UIA.ahk` library to interact with File Explorer's UI elements.

Place the required `UIA.ahk` file in the same directory as the script:

```text
ExplorerWheelNavigation/
├── ExplorerWheelNavigation.ahk
└── UIA.ahk
```

See the UI Automation library's documentation/license for installation and redistribution information.

### 3. Run the script

Double-click:

```text
ExplorerScrollNavigation.ahk
```

The script will run in the background.

Open Windows File Explorer and move the mouse over the main file/folder area.

## Usage

### File navigation

Place the cursor over the main file/folder area in File Explorer.

Then:

| Input | Action |
|---|---|
| Mouse Wheel Down | Select next file |
| Mouse Wheel Up | Select previous file |
| Double-click | Open selected file |
| Left click | Normal Explorer behavior |
| Right click | Normal Explorer context menu |
| Right click + Wheel | Normal Explorer scrolling |

The first wheel movement uses the cursor position to determine where navigation should begin.

Once navigation begins, the script maintains the current position independently of the cursor.

### Example

Suppose a folder contains:

```text
File 1
File 2
File 3
File 4
File 5
```

If the cursor is positioned over `File 3` and you scroll down:

```text
File 3
   ↓
File 4
   ↓
File 5
   ↓
File 1
   ↓
File 2
```

Navigation wraps around when the end of the folder is reached.

## How It Works

The script combines several Windows and AutoHotkey mechanisms.

### 1. Explorer window detection

The script identifies Windows File Explorer using its window classes:

```text
CabinetWClass
ExploreWClass
```

This prevents the custom navigation behavior from affecting unrelated applications.

### 2. File-list detection

The main Explorer file area is identified through the `DirectUIHWND` control.

This allows the script to distinguish the file/folder area from areas such as the navigation pane.

### 3. UI Automation

The UI Automation library is used to identify Explorer's currently focused file item and retrieve information such as:

- Item name
- Item type
- Bounding rectangle
- Clickable position

This allows the script to reposition the cursor onto the currently selected item.

### 4. Shell API navigation

Once navigation starts, the script obtains the folder's Shell item collection and maintains an index representing the current position.

This is important because Explorer may scroll as the selection moves.

Instead of asking:

> "Which file is underneath the mouse right now?"

for every wheel event, the script keeps track of:

```text
Current item
      ↓
Folder item collection
      ↓
Next / previous item
      ↓
Select item
      ↓
Move cursor to selected item
```

This prevents the navigation position from being reset when Explorer scrolls or when the cursor moves.

### 5. Input queue

Rapid mouse-wheel events are placed into a small queue and processed sequentially.

This prevents a burst of wheel input from overwhelming the selection logic and allows the script to handle fast scrolling more predictably.

## Project Architecture

The navigation flow can be simplified as:

```text
Mouse Wheel
     │
     ▼
Is Explorer?
     │
     ▼
Is main file area?
     │
     ▼
Queue wheel event
     │
     ▼
Navigation active?
    / \
  No   Yes
  │      │
  ▼      ▼
Find     Use
starting persistent
item     index
  │      │
  └──┬───┘
     ▼
Calculate next item
     │
     ▼
Select Shell item
     │
     ▼
Find focused UIA element
     │
     ▼
Move cursor to selected item
```

## Why UI Automation + Shell APIs?

The project uses two different mechanisms because they solve different problems.

**UI Automation** is useful for interacting with the visible Explorer interface and locating the selected item's position.

**Shell APIs** provide a more reliable representation of the folder's complete item collection, allowing navigation to continue even when items move off-screen.

Using both avoids relying entirely on the visual position of files.

## Known Limitations

- The script is designed primarily for Windows File Explorer.
- It depends on the structure and behavior of Windows Explorer.
- Changes to future versions of Windows Explorer could potentially affect compatibility.
- Duplicate file/folder names may make initial item identification less reliable in some situations.
- The UI Automation library is an external dependency.
- The current implementation is focused on single-item navigation rather than multi-selection.

## Future Improvements

Potential improvements include:

- Better handling of duplicate file/folder names.
- ExplorerScrollWheel does not work as intended when another tab is open and you use scroll wheel inside that tab.
- Configuration options for wheel sensitivity.
- User-configurable navigation speed.
- Optional horizontal-wheel support.
- Improved handling of different Explorer layouts.
- Optional enable/disable hotkey.
- Support for additional Explorer views.
- More robust error handling for transient Explorer/UI Automation failures.
- Packaging the script as a standalone executable.

## Development

This project was built incrementally around Windows 11 File Explorer behavior.

The implementation evolved from simple mouse-wheel interception into a persistent navigation system using UI Automation and Shell item indexing.

The main design goal is to make file navigation feel as immediate as navigating lists in applications such as music-production software.

## Contributing

Issues, suggestions, and improvements are welcome.

If you encounter a problem, please include:

- Windows version
- AutoHotkey version
- Explorer view being used
- Steps to reproduce the issue
- Whether the issue occurs consistently or only during rapid scrolling

## License

This project is released under the MIT License.

See [`LICENSE`](LICENSE) for details.

## Disclaimer

This project modifies mouse-wheel behavior within Windows File Explorer.

Use it at your own discretion. The script does not modify or replace Windows Explorer itself; it runs as an AutoHotkey automation script.