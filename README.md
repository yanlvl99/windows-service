# windows-service

A powerful Luau module for Windows window automation via FFI. Provides a Roblox-like API for interacting with Windows applications.

> **Requires**: [Lune Custom Build](https://github.com/yanlvl99/lune-custom-build) with FFI support.
> 
> **Documentation**: [https://yanlvl99.github.io/lune-custom-build-doc/](https://yanlvl99.github.io/lune-custom-build-doc/)

## Installation

```bash
lune --install windows-service
```

## Quick Start

```lua
local WindowsService = require("@windows-service")

-- Open Notepad and interact with it
local notepad = WindowsService.Spawn("notepad.exe")
if notepad then
    print("Window Handle:", notepad._ptr)
    print("Title:", notepad.Title)
    print("Process ID:", notepad.ProcessId)
    
    notepad:Write("Hello from Lune!")
    notepad:Close()
end
```

---

# Full API Reference

## Module Functions

### Process Creation

#### `Spawn(command: string, timeout: number?) -> Window?`

Starts a process and returns its main window. Works with single-instance apps (Notepad Win11, Explorer).

```lua
-- Basic usage
local notepad = WindowsService.Spawn("notepad.exe")

-- With timeout (default: 10 seconds)
local app = WindowsService.Spawn("myapp.exe", 30)

-- Opens unique windows even for single-instance apps
local win1 = WindowsService.Spawn("explorer.exe")
local win2 = WindowsService.Spawn("explorer.exe")
print(win1._ptr ~= win2._ptr) -- true (different HWNDs)
```

#### `SpawnAsync(command: string, timeout: number?) -> { window: Window?, ready: boolean }`

Non-blocking version of Spawn. Returns immediately with a result table.

```lua
local result = WindowsService.SpawnAsync("mspaint.exe", 10)

-- Do other work while waiting
while not result.ready do
    print("Waiting for Paint to open...")
    task.wait(0.1)
end

if result.window then
    print("Paint opened:", result.window.Title)
end
```

---

### Window Search Functions

#### `Find(titleOrFilter: string | function?) -> {Window}`

Returns array of all matching windows.

```lua
-- Find by title pattern
local chromes = WindowsService.Find("Chrome")
for _, w in ipairs(chromes) do
    print(w.Title)
end

-- Find by custom filter
local visible = WindowsService.Find(function(w)
    return w.IsVisible and w.ProcessName == "chrome.exe"
end)

-- Find all windows (no filter)
local all = WindowsService.Find()
```

#### `FindFirst(titleOrFilter: string | function?) -> Window?`

Returns the first matching window or nil.

```lua
local notepad = WindowsService.FindFirst("Notepad")
if notepad then
    notepad:Focus()
end

-- With filter
local bigWindow = WindowsService.FindFirst(function(w)
    return w.Width > 1000 and w.Height > 800
end)
```

#### `FindFirstOfClass(className: string) -> Window?`

Finds window by its Windows class name.

```lua
local explorer = WindowsService.FindFirstOfClass("CabinetWClass")
local notepad = WindowsService.FindFirstOfClass("Notepad")
local chrome = WindowsService.FindFirstOfClass("Chrome_WidgetWin_1")
```

#### `GetWindows(filter: function?) -> {Window}`

Lists all top-level windows, optionally filtered.

```lua
-- All windows
local all = WindowsService.GetWindows()

-- Only visible
local visible = WindowsService.GetWindows(function(w)
    return w.IsVisible
end)

-- Only minimized
local minimized = WindowsService.GetWindows(function(w)
    return w.IsMinimized
end)
```

#### `FindByPid(pid: number) -> {Window}`

Gets all windows belonging to a specific process ID.

```lua
local windows = WindowsService.FindByPid(1234)
for _, w in ipairs(windows) do
    print("Window:", w.Title)
end
```

#### `WaitFor(title: string, timeout: number?) -> Window?`

Blocks until a window with matching title appears.

```lua
print("Waiting for application to start...")
local app = WindowsService.WaitFor("My Application", 60)
if app then
    print("Application started!")
else
    print("Timeout waiting for application")
end
```

#### `GetPidByTitle(title: string) -> number?`

Gets the process ID of a window by title.

```lua
local pid = WindowsService.GetPidByTitle("Notepad")
if pid then
    print("Notepad PID:", pid)
end
```

---

### Special Windows

#### `GetFocusedWindow() -> Window`

Returns the currently focused window.

```lua
local focused = WindowsService.GetFocusedWindow()
print("Focused:", focused.Title)
```

#### `GetActiveWindow() -> Window`

Returns the active window in the current thread.

```lua
local active = WindowsService.GetActiveWindow()
```

#### `GetDesktopWindow() -> Window`

Returns the desktop window handle.

```lua
local desktop = WindowsService.GetDesktopWindow()
print("Desktop size:", desktop.Width, "x", desktop.Height)
```

---

### Global Input Functions

#### Cursor Control

```lua
-- Get cursor position
local pos = WindowsService.GetCursorPosition()
print("Cursor at:", pos.X, pos.Y)

-- Move cursor
WindowsService.SetCursorPosition(500, 300)

-- Click at screen coordinates
WindowsService.GlobalClick(500, 300)           -- Left click
WindowsService.GlobalClick(500, 300, "right")  -- Right click
```

#### Keyboard (Global)

```lua
-- Press and release a key
WindowsService.Tap(0x41)  -- Press 'A'

-- Hold/release keys
WindowsService.PressKey(0x11)   -- Hold Ctrl
WindowsService.ReleaseKey(0x11) -- Release Ctrl

-- Key combinations
WindowsService.Hotkey(0x11, 0x43)       -- Ctrl+C
WindowsService.Hotkey(0x11, 0x12, 0x53) -- Ctrl+Alt+S

-- Type text
WindowsService.Type("Hello World!")

-- Check key state
if WindowsService.IsKeyDown(0x10) then  -- Shift
    print("Shift is pressed")
end

-- Wait for key
local pressed = WindowsService.WaitForKey(0x1B, 10) -- Escape, 10s timeout
```

---

### Alert Dialogs

#### `Alert(hwnd: number, text: string, title: string, type: number) -> number`

Shows a MessageBox and returns the button clicked.

```lua
local result = WindowsService.Alert(0, "Are you sure?", "Confirm", 4) -- MB_YESNO
if result == 6 then -- IDYES
    print("User clicked Yes")
end
```

#### `AlertAsync(text: string, title?: string, type?: number) -> AlertInstance`

Non-blocking MessageBox with signal support.

```lua
local alert = WindowsService.AlertAsync("Processing complete!", "Done")
alert.Response:Connect(function(button, buttonId)
    print("User clicked:", button)
end)
```

---

## Window Object

### Properties

All properties are automatically updated when accessed (no caching of stale data).

| Property | Type | Read | Write | Description |
|----------|------|------|-------|-------------|
| `_ptr` | `number` | ✓ | ✗ | Window handle (HWND) - unique identifier |
| `Title` | `string` | ✓ | ✓ | Window title text |
| `ClassName` | `string` | ✓ | ✗ | Window class name |
| `ProcessId` | `number` | ✓ | ✗ | Process ID (PID) |
| `ProcessName` | `string` | ✓ | ✗ | Executable name (e.g., "notepad.exe") |
| `ProcessPath` | `string` | ✓ | ✗ | Full path to executable |
| `ThreadId` | `number` | ✓ | ✗ | Thread ID |
| `IsVisible` | `boolean` | ✓ | ✗ | Window visibility state |
| `IsEnabled` | `boolean` | ✓ | ✓ | Window enabled state |
| `IsMinimized` | `boolean` | ✓ | ✗ | Minimized state |
| `IsMaximized` | `boolean` | ✓ | ✗ | Maximized state |
| `IsFocused` | `boolean` | ✓ | ✗ | Has keyboard focus |
| `X` | `number` | ✓ | ✓ | Horizontal position |
| `Y` | `number` | ✓ | ✓ | Vertical position |
| `Width` | `number` | ✓ | ✓ | Window width |
| `Height` | `number` | ✓ | ✓ | Window height |
| `Bounds` | `Bounds` | ✓ | ✓ | `{X, Y, Width, Height}` |
| `ClientRect` | `table` | ✓ | ✗ | `{Width, Height}` of client area |
| `Style` | `number` | ✓ | ✓ | Window style flags |
| `ExStyle` | `number` | ✓ | ✓ | Extended style flags |
| `Transparency` | `number` | ✓ | ✓ | Alpha value (0-255) |
| `AlwaysOnTop` | `boolean` | ✓ | ✓ | Topmost state |
| `Parent` | `Window?` | ✓ | ✗ | Parent window |

```lua
local win = WindowsService.FindFirst("Notepad")

-- Read properties
print("Title:", win.Title)
print("Position:", win.X, win.Y)
print("Size:", win.Width, "x", win.Height)
print("Visible?", win.IsVisible)

-- Write properties
win.Title = "My Custom Title"
win.X = 100
win.Y = 100
win.Width = 800
win.Height = 600
win.Transparency = 200  -- Semi-transparent
win.AlwaysOnTop = true
```

---

### Methods with `:Wait()`

These methods return an `Awaitable` object that allows waiting for completion.

```lua
-- Execute immediately (non-blocking)
window:Minimize()

-- Execute and wait for completion
window:Minimize():Wait()

-- With timeout (returns false if timed out)
local success = window:Minimize():Wait(5)
if not success then
    print("Timeout!")
end
```

| Method | Description |
|--------|-------------|
| `Close()` | Closes the window (WM_CLOSE) |
| `Maximize()` | Maximizes the window |
| `Minimize()` | Minimizes the window |
| `Restore()` | Restores from minimized/maximized |
| `Focus()` | Brings to front and sets focus |
| `Show()` | Shows the window |
| `Hide()` | Hides the window |

```lua
local win = WindowsService.Spawn("notepad.exe")

-- Open, minimize, wait, restore, close
win:Focus():Wait()
task.wait(1)
win:Minimize():Wait()
task.wait(1)
win:Restore():Wait()
task.wait(1)
win:Close():Wait()
```

---

### Window Control Methods

#### Movement and Sizing

```lua
-- Move and resize
window:Move(100, 100, 800, 600)

-- Center on screen
window:Center()

-- Animate drag to position
window:DragTo(500, 300, 0.5)  -- duration in seconds

-- Shake effect
window:Shake(10, 0.3)  -- intensity, duration
```

#### Visibility and State

```lua
-- Show modes
window:Show()      -- Normal
window:Show(3)     -- Maximized
window:Show(6)     -- Minimized

-- Hide
window:Hide()

-- Flash in taskbar
window:Flash()

-- Bring to front without focus
window:BringToFront()

-- Always on top
window:SetTopMost(true)
window:SetTopMost(false)

-- Enable/disable
window:SetEnabled(false)  -- Grays out and disables input
window:SetEnabled(true)

-- Transparency overlay (click-through)
window:Pin(true)   -- Makes transparent and click-through
window:Unpin()     -- Restores normal state
```

#### Window Styles

```lua
-- Get/set window styles
local style = window.Style
local exStyle = window.ExStyle

-- Direct style modification
window:SetStyle(newStyle, newExStyle)

-- Force redraw
window:Redraw()
```

---

### Lifecycle Methods

```lua
-- Close gracefully (sends WM_CLOSE)
window:Close()

-- Force close (TerminateProcess)
window:ForceClose()

-- Kill process
local killed = window:Kill()

-- Wait for window to close
window:WaitForClose(30)  -- timeout in seconds

-- Detach from parent
window:Detach()

-- Set new parent
window:SetParent(otherWindow._ptr)

-- Destroy window object
window:Destroy()
```

---

### Input Methods

#### Text Input

```lua
-- Set window text content
window:SendText("Hello World")

-- Type text character by character (UTF-8 supported)
window:Write("Hello 世界 🎉")

-- Get window text
local text = window:GetText()
```

#### Keyboard Input

```lua
-- Press and release key
window:Tap(0x41)  -- 'A'

-- Hold key
window:PressKey(0x10)   -- Shift down
window:ReleaseKey(0x10) -- Shift up

-- Send key with modifiers
window:SendKey(0x41, true, false, true)  -- Ctrl+Shift+A
--            (vk,   ctrl,  alt,  shift)

-- Key combinations
window:Hotkey(0x11, 0x53)  -- Ctrl+S
```

#### Mouse Input

```lua
-- Click at client coordinates
window:Click(100, 50)

-- Send click message (doesn't move cursor)
window:SendClick(100, 50)

-- Scroll
window:ScrollUp(3)    -- 3 lines
window:ScrollDown(5)  -- 5 lines

-- Drag within window
window:DragTo(200, 150, 0.3)
```

---

### Child Window Methods

```lua
-- Get direct children
local children = window:GetChildren()
for _, child in ipairs(children) do
    print("Child:", child.ClassName, child.Title)
end

-- Get all descendants recursively
local all = window:GetAllChildren()

-- Get parent
local parent = window:GetParent()

-- Find child by class or title
local button = window:FindChild("Button")
local okBtn = window:FindChild("OK")
```

---

### Utility Methods

```lua
-- Check if window is responding
if window:IsResponding() then
    print("Window is responsive")
else
    print("Window is not responding!")
end

-- Start event monitoring
window:EnableMonitoring(0.1)  -- check every 100ms

-- Stop monitoring
window:StopMonitoring()
```

---

## Signals (Events)

Windows emit signals when state changes. Connect handlers with `:Connect()`.

```lua
local win = WindowsService.Spawn("notepad.exe")

-- Connect to events
win.Closed:Connect(function()
    print("Window was closed!")
end)

win.Minimized:Connect(function()
    print("Window was minimized!")
end)

win.Maximized:Connect(function()
    print("Window was maximized!")
end)

win.Focused:Connect(function()
    print("Window received focus!")
end)

win.Unfocused:Connect(function()
    print("Window lost focus!")
end)

win.Moved:Connect(function(x, y)
    print("Window moved to:", x, y)
end)

win.Resized:Connect(function(width, height)
    print("Window resized to:", width, "x", height)
end)

win.Changed:Connect(function(property, value)
    print("Property changed:", property, "=", value)
end)

-- Wait for signal
win.Closed:Wait()
print("Window was closed!")
```

### Signal Reference

| Signal | Parameters | Description |
|--------|------------|-------------|
| `Closed` | - | Window was closed |
| `Minimized` | - | Window was minimized |
| `Maximized` | - | Window was maximized |
| `Restored` | - | Window was restored |
| `Focused` | - | Window received keyboard focus |
| `Unfocused` | - | Window lost keyboard focus |
| `Moved` | `x: number, y: number` | Window position changed |
| `Resized` | `width: number, height: number` | Window size changed |
| `Changed` | `property: string, value: any` | Any monitored property changed |

---

## Enums

Access via `WindowsService.Enums`:

```lua
local Enums = WindowsService.Enums

-- Virtual Keys
local VK = Enums.VirtualKey
window:Tap(VK.VK_RETURN)   -- Enter
window:Tap(VK.VK_ESCAPE)   -- Escape
window:Tap(VK.VK_SPACE)    -- Space
window:Tap(VK.VK_TAB)      -- Tab
window:Hotkey(VK.VK_CONTROL, VK.VK_C)  -- Ctrl+C

-- Show Window commands
local SW = Enums.ShowWindow
window:Show(SW.SW_MAXIMIZE)
window:Show(SW.SW_MINIMIZE)
window:Show(SW.SW_RESTORE)
window:Show(SW.SW_HIDE)

-- Window Styles
local WS = Enums.WindowStyle
if bit32.band(window.Style, WS.WS_VISIBLE) ~= 0 then
    print("Window is visible")
end
```

### Common Virtual Keys

| Key | Code | Key | Code |
|-----|------|-----|------|
| `VK_RETURN` | 0x0D | `VK_ESCAPE` | 0x1B |
| `VK_SPACE` | 0x20 | `VK_TAB` | 0x09 |
| `VK_BACK` | 0x08 | `VK_DELETE` | 0x2E |
| `VK_CONTROL` | 0x11 | `VK_SHIFT` | 0x10 |
| `VK_MENU` | 0x12 | `VK_F1-F12` | 0x70-0x7B |
| `VK_LEFT` | 0x25 | `VK_UP` | 0x26 |
| `VK_RIGHT` | 0x27 | `VK_DOWN` | 0x28 |
| `A-Z` | 0x41-0x5A | `0-9` | 0x30-0x39 |

---

## Types

```lua
export type Window = {
    _ptr: number,                -- HWND (unique identifier)
    Title: string,
    ClassName: string,
    ProcessId: number,
    ProcessName: string,
    ProcessPath: string,
    ThreadId: number,
    IsVisible: boolean,
    IsEnabled: boolean,
    IsMinimized: boolean,
    IsMaximized: boolean,
    IsFocused: boolean,
    X: number, Y: number,
    Width: number, Height: number,
    Bounds: Bounds,
    ClientRect: { Width: number, Height: number },
    Style: number,
    ExStyle: number,
    Transparency: number,
    AlwaysOnTop: boolean,
    Parent: Window?,
    
    -- Methods...
    Close: () -> Awaitable,
    Minimize: () -> Awaitable,
    -- etc.
}

export type Awaitable = {
    Wait: (timeout: number?) -> boolean
}

export type Bounds = { X: number, Y: number, Width: number, Height: number }
export type Point = { X: number, Y: number }
export type AlertInstance = { Response: Signal<string, number> }
```

---

## Limitations

- **UWP/Modern Apps**: Apps like Notepad on Windows 11 use single-instance model. `Spawn` handles this by tracking unique HWNDs instead of PIDs.
- **Permissions**: Some operations require Administrator privileges.
- **GUI Thread**: Window operations should run on a thread with a message loop.

---

## Complete Examples

### Window Manager

```lua
local WindowsService = require("@windows-service")
local task = require("@lune/task")

-- Find all Chrome windows and close them
local chromes = WindowsService.Find("Chrome")
print("Found", #chromes, "Chrome windows")

for _, chrome in ipairs(chromes) do
    chrome:Close()
end
```

### Keyboard Macro

```lua
local WindowsService = require("@windows-service")
local task = require("@lune/task")

local notepad = WindowsService.Spawn("notepad.exe")
if notepad then
    notepad:Focus():Wait()
    task.wait(0.5)
    
    -- Type a message
    notepad:Write("Hello from Lune automation!\n")
    
    -- Select all (Ctrl+A)
    notepad:Hotkey(0x11, 0x41)
    task.wait(0.1)
    
    -- Copy (Ctrl+C)
    notepad:Hotkey(0x11, 0x43)
    
    task.wait(2)
    notepad:Close()
end
```

### Event-Driven Monitoring

```lua
local WindowsService = require("@windows-service")

local win = WindowsService.WaitFor("My Application", 60)
if win then
    print("Application started!")
    
    win.Minimized:Connect(function()
        print("User minimized the app")
    end)
    
    win.Closed:Connect(function()
        print("Application closed")
    end)
    
    -- Wait until closed
    win.Closed:Wait()
    print("Goodbye!")
end
```

### Multi-Instance Management

```lua
local WindowsService = require("@windows-service")
local task = require("@lune/task")

-- Open 3 Paint windows
local windows = {}
for i = 1, 3 do
    local win = WindowsService.Spawn("mspaint.exe", 10)
    if win then
        table.insert(windows, win)
        print("Opened Paint", i, "HWND:", win._ptr)
    end
end

-- Position them side by side
for i, win in ipairs(windows) do
    win:Move((i - 1) * 400, 100, 400, 600)
end

task.wait(3)

-- Close all
for _, win in ipairs(windows) do
    win:Close()
end
```
