--!strict
local Signal = require("@signals-like-roblox")

export type AlertInstance = { Response: Signal.Signal<string, number>, _task: thread? }
export type Bounds = { X: number, Y: number, Width: number, Height: number }
export type Point = { X: number, Y: number }

--[[
	@Window Janela
	@WindowModule Janela
]]
export type Window = {
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
	Transparency: number,
	AlwaysOnTop: boolean,
	X: number,
	Y: number,
	Width: number,
	Height: number,
	Style: number,
	ExStyle: number,
	Parent: Window?,
	Bounds: Bounds,
	ClientRect: { Width: number, Height: number },

	Show: (self: Window, mode: number?) -> (),
	Hide: (self: Window) -> (),
	Minimize: (self: Window) -> (),
	Maximize: (self: Window) -> (),
	Restore: (self: Window) -> (),
	Close: (self: Window) -> (),
	Flash: (self: Window) -> (),
	Move: (self: Window, x: number, y: number, w: number, h: number) -> (),
	SetFocus: (self: Window) -> (),
	Click: (self: Window, x: number, y: number) -> (),
	SetTopMost: (self: Window, enabled: boolean) -> (),
	BringToFront: (self: Window) -> (),
	EnableMonitoring: (self: Window, rate: number?) -> (),
	StopMonitoring: (self: Window) -> (),
	Destroy: (self: Window) -> (),

	SendText: (self: Window, text: string) -> (),
	TypeText: (self: Window, text: string) -> (),
	Write: (self: Window, text: string) -> (),
	GetText: (self: Window) -> string,
	SendKey: (self: Window, vk: number, ctrl: boolean?, alt: boolean?, shift: boolean?) -> (),
	PressKey: (self: Window, vk: number) -> (),
	ReleaseKey: (self: Window, vk: number) -> (),
	Tap: (self: Window, vk: number) -> (),
	Hotkey: (self: Window, ...number) -> (),

	IsResponding: (self: Window) -> boolean,
	WaitForClose: (self: Window, timeout: number?) -> boolean,
	GetChildren: (self: Window) -> { Window },
	GetAllChildren: (self: Window) -> { Window },
	GetParent: (self: Window) -> Window?,
	FindChild: (self: Window, classOrTitle: string) -> Window?,

	SetStyle: (self: Window, style: number, exStyle: number?) -> (),
	SetEnabled: (self: Window, enabled: boolean) -> (),
	SetParent: (self: Window, parent: number) -> (),
	Redraw: (self: Window) -> (),
	ForceClose: (self: Window) -> (),
	Shake: (self: Window, intensity: number?, duration: number?) -> (),
	Center: (self: Window) -> (),
	Kill: (self: Window) -> boolean,

	SendClick: (self: Window, x: number, y: number) -> (),
	ScrollUp: (self: Window, amount: number?) -> (),
	ScrollDown: (self: Window, amount: number?) -> (),
	DragTo: (self: Window, x: number, y: number, duration: number?) -> (),
	Detach: (self: Window) -> (),
	Pin: (self: Window, clickThrough: boolean?) -> (),
	Unpin: (self: Window) -> (),

	Closed: Signal.Signal<>,
	Moved: Signal.Signal<number, number>,
	Resized: Signal.Signal<number, number>,
	Minimized: Signal.Signal<>,
	Maximized: Signal.Signal<>,
	Restored: Signal.Signal<>,
	Focused: Signal.Signal<>,
	Unfocused: Signal.Signal<>,
	Changed: Signal.Signal<string, any>,
}

export type WindowModule = {
	new: (cls: string?, title: string?) -> Window?,
	fromPointer: (ptr: any) -> Window,
	GetWindows: (filter: ((Window) -> boolean)?) -> { Window },
	GetFocusedWindow: () -> Window,
	GetActiveWindow: () -> Window,
	GetDesktopWindow: () -> Window,
	FindByPid: (pid: number) -> { Window },
	Alert: (hwnd: number, text: string, title: string, type: number) -> number,
	AlertAsync: (text: string, title: string?, type: number?) -> AlertInstance,
	WaitFor: (title: string, timeout: number?) -> Window?,
	GetCursorPosition: () -> Point,
	SetCursorPosition: (x: number, y: number) -> (),
	GlobalClick: (x: number, y: number, button: string?) -> (),
	GetPidByTitle: (title: string) -> number?,
	PressKey: (vk: number) -> (),
	ReleaseKey: (vk: number) -> (),
	Tap: (vk: number) -> (),
	Hotkey: (...number) -> (),
	Type: (text: string) -> (),
	IsKeyDown: (vk: number) -> boolean,
	WaitForKey: (vk: number, timeout: number?) -> boolean,
	Enums: any,
}

return {}
