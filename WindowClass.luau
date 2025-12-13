-- WindowClass.luau - Definição da classe Window usando ffi-like-roblox
local defineClass = require("@ffi-like-roblox")
local ffi = require("@lune/ffi")
local Enums = require("@windows-service/Enums")
local Helpers = require("@windows-service/Helpers")
local Monitoring = require("@windows-service/Monitoring")

local HWND_TYPE = Helpers.HWND_TYPE
local getRect = Helpers.getRect
local getString = Helpers.getString

local WindowClass = defineClass({
	Name = "Window",
	Dll = "user32.dll",

	Constructor = function(lib, cls, name)
		if not cls and name then
			local found = 0
			local t = name:lower()
			local cb = ffi.callback(function(h)
				local b = ffi.buffer(512)
				lib:call("GetWindowTextA", "i32", { HWND_TYPE, "pointer", "i32" }, h, b.ptr, 512)
				if b:readString():lower():find(t, 1, true) then
					found = h
					return 0
				end
				return 1
			end, "i32", { HWND_TYPE, "i32" })
			lib:call("EnumWindows", "i32", { "pointer", "i32" }, cb.ptr, 0)
			return found
		else
			local args = { cls and "string" or "u64", name and "string" or "u64" }
			local vals = { cls or 0, name or 0 }
			if cls then
				local b = ffi.buffer(#cls + 1)
				b:writeString(0, cls)
				vals[1], args[1] = b.ptr, "pointer"
			end
			if name then
				local b = ffi.buffer(#name + 1)
				b:writeString(0, name)
				vals[2], args[2] = b.ptr, "pointer"
			end
			return lib:call("FindWindowA", HWND_TYPE, args, vals[1], vals[2])
		end
	end,

	Properties = {
		Title = {
			type = "string",
			set = "SetWindowTextA",
			get = function(l, p)
				return getString(l, "GetWindowTextA", p)
			end,
		},
		ClassName = {
			type = "string",
			get = function(l, p)
				return getString(l, "GetClassNameA", p)
			end,
		},
		IsVisible = { type = "bool", get = "IsWindowVisible" },
		IsEnabled = {
			type = "bool",
			get = "IsWindowEnabled",
			set = function(l, p, e)
				l:call("EnableWindow", "bool", { HWND_TYPE, "bool" }, p, e)
			end,
		},
		IsMinimized = {
			type = "bool",
			get = function(l, p)
				local style = l:call("GetWindowLongA", "i32", { HWND_TYPE, "i32" }, p, -16)
				return bit32.band(style, Enums.WindowStyle.WS_MINIMIZE) ~= 0
			end,
		},
		IsMaximized = {
			type = "bool",
			get = function(l, p)
				local style = l:call("GetWindowLongA", "i32", { HWND_TYPE, "i32" }, p, -16)
				return bit32.band(style, Enums.WindowStyle.WS_MAXIMIZE) ~= 0
			end,
		},
		ProcessId = {
			type = "u32",
			get = function(l, p)
				local b = ffi.buffer(4)
				l:call("GetWindowThreadProcessId", "u32", { HWND_TYPE, "pointer" }, p, b.ptr)
				return b:read(0, "u32")
			end,
		},
		ProcessName = {
			type = "string",
			get = function(l, p)
				local pidBuf = ffi.buffer(4)
				l:call("GetWindowThreadProcessId", "u32", { HWND_TYPE, "pointer" }, p, pidBuf.ptr)
				local pid = pidBuf:read(0, "u32")
				if pid == 0 then
					return ""
				end
				local kernel32 = ffi.open("kernel32.dll")
				local handle = kernel32:call("OpenProcess", "pointer", { "u32", "bool", "u32" }, 0x1000, false, pid)
				if not handle or ffi.isNull(handle) then
					return ""
				end
				local pathBuf = ffi.buffer(260)
				local sizeBuf = ffi.buffer(4)
				sizeBuf:write(0, "u32", 260)
				kernel32:call(
					"QueryFullProcessImageNameA",
					"bool",
					{ "pointer", "u32", "pointer", "pointer" },
					handle,
					0,
					pathBuf.ptr,
					sizeBuf.ptr
				)
				kernel32:call("CloseHandle", "bool", { "pointer" }, handle)
				local fullPath = pathBuf:readString()
				return fullPath:match("[^\\]+$") or fullPath
			end,
		},
		ProcessPath = {
			type = "string",
			get = function(l, p)
				local pidBuf = ffi.buffer(4)
				l:call("GetWindowThreadProcessId", "u32", { HWND_TYPE, "pointer" }, p, pidBuf.ptr)
				local pid = pidBuf:read(0, "u32")
				if pid == 0 then
					return ""
				end
				local kernel32 = ffi.open("kernel32.dll")
				local handle = kernel32:call("OpenProcess", "pointer", { "u32", "bool", "u32" }, 0x1000, false, pid)
				if not handle or ffi.isNull(handle) then
					return ""
				end
				local pathBuf = ffi.buffer(260)
				local sizeBuf = ffi.buffer(4)
				sizeBuf:write(0, "u32", 260)
				kernel32:call(
					"QueryFullProcessImageNameA",
					"bool",
					{ "pointer", "u32", "pointer", "pointer" },
					handle,
					0,
					pathBuf.ptr,
					sizeBuf.ptr
				)
				kernel32:call("CloseHandle", "bool", { "pointer" }, handle)
				return pathBuf:readString()
			end,
		},
		ThreadId = {
			type = "u32",
			get = function(l, p)
				local b = ffi.buffer(4)
				return l:call("GetWindowThreadProcessId", "u32", { HWND_TYPE, "pointer" }, p, b.ptr)
			end,
		},
		IsFocused = {
			type = "bool",
			get = function(l, p)
				return l:call("GetForegroundWindow", HWND_TYPE, {}) == p
			end,
		},
		Bounds = {
			type = "table",
			get = function(l, p)
				local r = getRect(l, p)
				if not r then
					return { X = 0, Y = 0, Width = 0, Height = 0 }
				end
				return { X = r.l, Y = r.t, Width = r.r - r.l, Height = r.b - r.t }
			end,
		},
		ClientRect = {
			type = "table",
			get = function(l, p)
				local b = ffi.buffer(16)
				l:call("GetClientRect", "bool", { HWND_TYPE, "pointer" }, p, b.ptr)
				return { Width = b:read(8, "i32") - b:read(0, "i32"), Height = b:read(12, "i32") - b:read(4, "i32") }
			end,
		},
		Style = {
			type = "i32",
			get = function(l, p)
				return l:call("GetWindowLongA", "i32", { HWND_TYPE, "i32" }, p, -16)
			end,
			set = function(l, p, s)
				l:call("SetWindowLongA", "i32", { HWND_TYPE, "i32", "i32" }, p, -16, s)
			end,
		},
		ExStyle = {
			type = "i32",
			get = function(l, p)
				return l:call("GetWindowLongA", "i32", { HWND_TYPE, "i32" }, p, -20)
			end,
			set = function(l, p, s)
				l:call("SetWindowLongA", "i32", { HWND_TYPE, "i32", "i32" }, p, -20, s)
			end,
		},
		Transparency = {
			type = "f64",
			get = function()
				return 0
			end,
			set = function(l, p, a)
				local ex = l:call("GetWindowLongA", "i32", { HWND_TYPE, "i32" }, p, -20)
				l:call("SetWindowLongA", "i32", { HWND_TYPE, "i32", "i32" }, p, -20, bit32.bor(ex, 0x80000))
				l:call(
					"SetLayeredWindowAttributes",
					"bool",
					{ HWND_TYPE, "i32", "u8", "i32" },
					p,
					0,
					math.floor((1 - a) * 255),
					2
				)
			end,
		},
		AlwaysOnTop = {
			type = "bool",
			get = function(l, p)
				return bit32.band(l:call("GetWindowLongA", "i32", { HWND_TYPE, "i32" }, p, -20), 0x8) ~= 0
			end,
			set = function(l, p, e)
				l:call(
					"SetWindowPos",
					"bool",
					{ HWND_TYPE, "i64", "i32", "i32", "i32", "i32", "i32" },
					p,
					e and -1 or -2,
					0,
					0,
					0,
					0,
					3
				)
			end,
		},
		X = {
			type = "i32",
			get = function(l, p)
				local r = getRect(l, p)
				return r and r.l or 0
			end,
			set = function(l, p, v)
				local r = getRect(l, p)
				if r then
					l:call(
						"MoveWindow",
						"bool",
						{ HWND_TYPE, "i32", "i32", "i32", "i32", "bool" },
						p,
						v,
						r.t,
						r.r - r.l,
						r.b - r.t,
						true
					)
				end
			end,
		},
		Y = {
			type = "i32",
			get = function(l, p)
				local r = getRect(l, p)
				return r and r.t or 0
			end,
			set = function(l, p, v)
				local r = getRect(l, p)
				if r then
					l:call(
						"MoveWindow",
						"bool",
						{ HWND_TYPE, "i32", "i32", "i32", "i32", "bool" },
						p,
						r.l,
						v,
						r.r - r.l,
						r.b - r.t,
						true
					)
				end
			end,
		},
		Width = {
			type = "i32",
			get = function(l, p)
				local r = getRect(l, p)
				return r and (r.r - r.l) or 0
			end,
			set = function(l, p, v)
				local r = getRect(l, p)
				if r then
					l:call(
						"MoveWindow",
						"bool",
						{ HWND_TYPE, "i32", "i32", "i32", "i32", "bool" },
						p,
						r.l,
						r.t,
						v,
						r.b - r.t,
						true
					)
				end
			end,
		},
		Height = {
			type = "i32",
			get = function(l, p)
				local r = getRect(l, p)
				return r and (r.b - r.t) or 0
			end,
			set = function(l, p, v)
				local r = getRect(l, p)
				if r then
					l:call(
						"MoveWindow",
						"bool",
						{ HWND_TYPE, "i32", "i32", "i32", "i32", "bool" },
						p,
						r.l,
						r.t,
						r.r - r.l,
						v,
						true
					)
				end
			end,
		},
		Parent = {
			type = "u64",
			get = function(l, p)
				local h = l:call("GetParent", HWND_TYPE, { HWND_TYPE }, p)
				return h ~= 0 and h or nil
			end,
		},
	},

	Methods = {
		-- Show, Hide, Minimize, Maximize, Restore, Close, Focus agora são Actions em InstanceMethods
		Flash = {
			symbol = "FlashWindow",
			ret = "bool",
			args = {},
			wrapper = function(l, p)
				return l:call("FlashWindow", "bool", { HWND_TYPE, "bool" }, p, true)
			end,
		},
		Move = {
			symbol = "MoveWindow",
			ret = "bool",
			args = { "i32", "i32", "i32", "i32" },
			wrapper = function(l, p, x, y, w, h)
				return l:call(
					"MoveWindow",
					"bool",
					{ HWND_TYPE, "i32", "i32", "i32", "i32", "bool" },
					p,
					x,
					y,
					w,
					h,
					true
				)
			end,
		},
		SetTopMost = {
			symbol = "SetWindowPos",
			ret = "bool",
			args = { "bool" },
			wrapper = function(l, p, e)
				return l:call(
					"SetWindowPos",
					"bool",
					{ HWND_TYPE, "i64", "i32", "i32", "i32", "i32", "i32" },
					p,
					e and -1 or -2,
					0,
					0,
					0,
					0,
					3
				)
			end,
		},
		BringToFront = { symbol = "BringWindowToTop", ret = "bool", args = {} },
		Click = {
			symbol = "SetCursorPos",
			ret = "void",
			args = { "i32", "i32" },
			wrapper = function(l, p, x, y)
				local r = getRect(l, p)
				if r then
					l:call("SetCursorPos", "bool", { "i32", "i32" }, r.l + x, r.t + y)
					l:call("mouse_event", "void", { "i32", "i32", "i32", "i32", "u64" }, 2, 0, 0, 0, 0)
					l:call("mouse_event", "void", { "i32", "i32", "i32", "i32", "u64" }, 4, 0, 0, 0, 0)
				end
			end,
		},
		SendText = {
			symbol = "SendMessageA",
			ret = "i32",
			args = { "string" },
			wrapper = function(l, p, txt)
				local b = ffi.buffer(#txt + 1)
				b:writeString(0, txt)
				l:call("SendMessageA", "i64", { HWND_TYPE, "u32", "u64", "pointer" }, p, 0x00C2, 1, b.ptr)
			end,
		},
		TypeText = {
			symbol = "PostMessageA",
			ret = "void",
			args = { "string" },
			wrapper = function(l, p, txt)
				for i = 1, #txt do
					l:call(
						"PostMessageA",
						"bool",
						{ HWND_TYPE, "u32", "u64", "i64" },
						p,
						0x0102,
						string.byte(txt, i),
						0
					)
				end
			end,
		},
		SendKey = {
			symbol = "PostMessageA",
			ret = "bool",
			args = { "i32", "bool", "bool", "bool" },
			wrapper = function(l, p, vk, ctrl, alt, shift)
				if ctrl then
					l:call("PostMessageA", "bool", { HWND_TYPE, "u32", "u64", "i64" }, p, 0x100, 0x11, 0)
				end
				if alt then
					l:call("PostMessageA", "bool", { HWND_TYPE, "u32", "u64", "i64" }, p, 0x100, 0x12, 0)
				end
				if shift then
					l:call("PostMessageA", "bool", { HWND_TYPE, "u32", "u64", "i64" }, p, 0x100, 0x10, 0)
				end
				l:call("PostMessageA", "bool", { HWND_TYPE, "u32", "u64", "i64" }, p, 0x100, vk, 0)
				l:call("PostMessageA", "bool", { HWND_TYPE, "u32", "u64", "i64" }, p, 0x101, vk, 0)
				if shift then
					l:call("PostMessageA", "bool", { HWND_TYPE, "u32", "u64", "i64" }, p, 0x101, 0x10, 0)
				end
				if alt then
					l:call("PostMessageA", "bool", { HWND_TYPE, "u32", "u64", "i64" }, p, 0x101, 0x12, 0)
				end
				if ctrl then
					l:call("PostMessageA", "bool", { HWND_TYPE, "u32", "u64", "i64" }, p, 0x101, 0x11, 0)
				end
			end,
		},
		GetText = {
			symbol = "GetWindowTextA",
			ret = "string",
			args = {},
			wrapper = function(l, p)
				return getString(l, "GetWindowTextA", p)
			end,
		},
		IsResponding = {
			symbol = "SendMessageTimeoutA",
			ret = "bool",
			args = {},
			wrapper = function(l, p)
				local result = ffi.buffer(8)
				local ret = l:call(
					"SendMessageTimeoutA",
					"i32",
					{ HWND_TYPE, "u32", "u64", "i64", "u32", "u32", "pointer" },
					p,
					0,
					0,
					0,
					2,
					1000,
					result.ptr
				)
				return ret ~= 0
			end,
		},
		SetEnabled = { symbol = "EnableWindow", ret = "bool", args = { "bool" } },
		SetStyle = {
			symbol = "SetWindowLongA",
			ret = "void",
			args = { "i32", "i32" },
			wrapper = function(l, p, s, ex)
				l:call("SetWindowLongA", "i32", { HWND_TYPE, "i32", "i32" }, p, -16, s)
				if ex then
					l:call("SetWindowLongA", "i32", { HWND_TYPE, "i32", "i32" }, p, -20, ex)
				end
				l:call(
					"SetWindowPos",
					"bool",
					{ HWND_TYPE, "i64", "i32", "i32", "i32", "i32", "i32" },
					p,
					0,
					0,
					0,
					0,
					0,
					0x27
				)
			end,
		},
		-- Força redesenho da janela
		Redraw = {
			symbol = "InvalidateRect",
			ret = "bool",
			args = {},
			wrapper = function(l, p)
				l:call("InvalidateRect", "bool", { HWND_TYPE, "pointer", "bool" }, p, ffi.null, true)
				l:call("UpdateWindow", "bool", { HWND_TYPE }, p)
			end,
		},
		-- Envia WM_DESTROY para forçar fechamento
		ForceClose = {
			symbol = "DestroyWindow",
			ret = "bool",
			args = {},
			wrapper = function(l, p)
				return l:call("PostMessageA", "bool", { HWND_TYPE, "u32", "u64", "i64" }, p, 0x0010, 0, 0)
			end,
		},
		-- Clique em background via WM_LBUTTONDOWN/UP
		SendClick = {
			symbol = "PostMessageA",
			ret = "void",
			args = { "i32", "i32" },
			wrapper = function(l, p, x, y)
				local lParam = bit32.bor(bit32.band(y, 0xFFFF) * 0x10000, bit32.band(x, 0xFFFF))
				l:call("PostMessageA", "bool", { HWND_TYPE, "u32", "u64", "i64" }, p, 0x0201, 1, lParam) -- WM_LBUTTONDOWN
				l:call("PostMessageA", "bool", { HWND_TYPE, "u32", "u64", "i64" }, p, 0x0202, 0, lParam) -- WM_LBUTTONUP
			end,
		},
		-- Scroll via WM_MOUSEWHEEL
		ScrollUp = {
			symbol = "PostMessageA",
			ret = "void",
			args = { "i32" },
			wrapper = function(l, p, amount)
				local delta = (amount or 3) * 120
				l:call("PostMessageA", "bool", { HWND_TYPE, "u32", "u64", "i64" }, p, 0x020A, delta * 0x10000, 0)
			end,
		},
		ScrollDown = {
			symbol = "PostMessageA",
			ret = "void",
			args = { "i32" },
			wrapper = function(l, p, amount)
				local delta = -(amount or 3) * 120
				l:call("PostMessageA", "bool", { HWND_TYPE, "u32", "u64", "i64" }, p, 0x020A, delta * 0x10000, 0)
			end,
		},
		-- Altera janela pai
		SetParent = {
			symbol = "SetParent",
			ret = "u64",
			args = { "u64" },
		},
	},

	Events = {
		Closed = true,
		Moved = true,
		Resized = true,
		Minimized = true,
		Maximized = true,
		Restored = true,
		Focused = true,
		Unfocused = true,
		Changed = true,
	},

	-- Função de monitoramento para lazy activation
	MonitoringFunc = Monitoring.startMonitoring,
	MonitoringRate = 0.1,

	Static = {
		Alert = {
			symbol = "MessageBoxA",
			ret = "i32",
			args = { "u64", "pointer", "pointer", "i32" },
			wrapper = function(lib, _, a1, a2, a3, a4)
				local p, txt, tit, typ =
					(type(a1) == "table" and a2 or a1),
					(type(a1) == "table" and a3 or a2),
					(type(a1) == "table" and a4 or a3),
					(if type(a1) == "table" then nil else a4)
				local bT = ffi.buffer(#tostring(txt or "Alert") + 1)
				bT:writeString(0, tostring(txt or "Alert"))
				local bC = ffi.buffer(#tostring(tit or "Lune") + 1)
				bC:writeString(0, tostring(tit or "Lune"))
				local finalType = (typ or 0) + Enums.MessageBox.Flag.TopMost
				return lib:call(
					"MessageBoxA",
					"i32",
					{ "u64", "pointer", "pointer", "i32" },
					(type(p) == "number" and p or 0),
					bT.ptr,
					bC.ptr,
					finalType
				)
			end,
		},
		_EnumWindows = { symbol = "EnumWindows", ret = "i32", args = { "pointer", "i32" } },
	},
})

return WindowClass
