-- src/Window.luau
local defineClass = require("@ffi-like-roblox")
local ffi = require("@lune/ffi")
local Signal = require("@signals-like-roblox")
local task = require("@lune/task")
local Enums = require("@self/Enums") -- Usando @self como pediu

local HWND_TYPE = "u64"

-- ============================================================
-- 1. TIPAGEM
-- ============================================================
export type AlertInstance = {
	Response: Signal.Signal<string, number>,
	_task: thread?
}

export type Window = {
	Title: string, ClassName: string, ProcessId: number,
	IsVisible: boolean, IsEnabled: boolean, Transparency: number, AlwaysOnTop: boolean,
	X: number, Y: number, Width: number, Height: number,
	Show: (self: Window, m: number) -> (), Hide: (self: Window) -> (), Minimize: (self: Window) -> (),
	Maximize: (self: Window) -> (), Restore: (self: Window) -> (), Close: (self: Window) -> (),
	Flash: (self: Window) -> (), Move: (self: Window, x:number, y:number, w:number, h:number) -> (),
	SetFocus: (self: Window) -> (), Click: (self: Window, x:number, y:number) -> (), 
	SetTopMost: (self: Window, e:boolean) -> (),
	EnableMonitoring: (self: Window, rate: number?) -> (), -- Injetado
	Closed: Signal.Signal<>, Moved: Signal.Signal<number, number>, Resized: Signal.Signal<number, number>
}

-- Helpers locais
local function getRect(lib, hwnd)
	local b = ffi.buffer(16)
	if lib:call("GetWindowRect", "i32", {HWND_TYPE,"pointer"}, hwnd, b.ptr) == 0 then return nil end
	return {l=b:read(0,"i32"), t=b:read(4,"i32"), r=b:read(8,"i32"), b=b:read(12,"i32")}
end
local function getString(lib, func, hwnd)
	local b = ffi.buffer(512)
	lib:call(func, "i32", {HWND_TYPE,"pointer","i32"}, hwnd, b.ptr, 512)
	return b:readString()
end

-- ============================================================
-- 2. DEFINIÇÃO DA CLASSE (MOTOR FFI)
-- ============================================================
local WindowImpl = defineClass({
	Name = "Window", Dll = "user32.dll",

	Constructor = function(lib, cls, name)
		if not cls and name then
			local found = 0; local t = name:lower()
			local cb = ffi.callback(function(h)
				local b = ffi.buffer(512); lib:call("GetWindowTextA", "i32", {HWND_TYPE,"pointer","i32"}, h, b.ptr, 512)
				if b:readString():lower():find(t, 1, true) then found=h; return 0 end
				return 1
			end, "i32", {HWND_TYPE,"i32"})
			lib:call("EnumWindows", "i32", {"pointer","i32"}, cb.ptr, 0)
			return found
		else
			local args, vals = {cls and "string" or "u64", name and "string" or "u64"}, {cls or 0, name or 0}
			if cls then local b=ffi.buffer(#cls+1); b:writeString(0,cls); vals[1]=b.ptr; args[1]="pointer" end
			if name then local b=ffi.buffer(#name+1); b:writeString(0,name); vals[2]=b.ptr; args[2]="pointer" end
			return lib:call("FindWindowA", HWND_TYPE, args, vals[1], vals[2])
		end
	end,

	Properties = {
		Title = {type="string", set="SetWindowTextA", get=function(l,p) return getString(l, "GetWindowTextA", p) end},
		ClassName = {type="string", get=function(l,p) return getString(l, "GetClassNameA", p) end},
		IsVisible = {type="bool", get="IsWindowVisible"}, ProcessId = {type="u32", get=function(l,p) local b=ffi.buffer(4); l:call("GetWindowThreadProcessId", "u32", {HWND_TYPE,"pointer"}, p, b.ptr); return b:read(0,"u32") end},
		Transparency = {type="f64", get=function() return 0 end, set=function(l,p,a)
			local ex = l:call("GetWindowLongA", "i32", {HWND_TYPE,"i32"}, p, -20)
			l:call("SetWindowLongA", "i32", {HWND_TYPE,"i32","i32"}, p, -20, ex + 0x80000)
			l:call("SetLayeredWindowAttributes", "bool", {HWND_TYPE,"i32","u8","i32"}, p, 0, math.floor((1-a)*255), 2)
		end},
		AlwaysOnTop = {type="bool", get=function() return false end, set=function(l,p,e)
			l:call("SetWindowPos", "bool", {HWND_TYPE,"i64","i32","i32","i32","i32","i32"}, p, e and -1 or -2, 0,0,0,0, 3)
		end},
		X = {type="i32", get=function(l,p) local r=getRect(l,p); return r and r.l or 0 end},
		Y = {type="i32", get=function(l,p) local r=getRect(l,p); return r and r.t or 0 end},
		Width = {type="i32", get=function(l,p) local r=getRect(l,p); return r and (r.r-r.l) or 0 end},
		Height = {type="i32", get=function(l,p) local r=getRect(l,p); return r and (r.b-r.t) or 0 end},
	},

	Methods = {
		Show = {symbol="ShowWindow", ret="bool", args={"i32"}, wrapper=function(l,p) return l:call("ShowWindow", "bool", {HWND_TYPE,"i32"}, p, 5) end},
		Hide = {symbol="ShowWindow", ret="bool", args={"i32"}, wrapper=function(l,p) return l:call("ShowWindow", "bool", {HWND_TYPE,"i32"}, p, 0) end},
		Minimize = {symbol="ShowWindow", ret="bool", args={"i32"}, wrapper=function(l,p) return l:call("ShowWindow", "bool", {HWND_TYPE,"i32"}, p, 6) end},
		Maximize = {symbol="ShowWindow", ret="bool", args={"i32"}, wrapper=function(l,p) return l:call("ShowWindow", "bool", {HWND_TYPE,"i32"}, p, 3) end},
		Restore = {symbol="ShowWindow", ret="bool", args={"i32"}, wrapper=function(l,p) return l:call("ShowWindow", "bool", {HWND_TYPE,"i32"}, p, 9) end},
		Flash = {symbol="FlashWindow", ret="bool", args={"bool"}, wrapper=function(l,p) return l:call("FlashWindow", "bool", {HWND_TYPE,"bool"}, p, true) end},
		Move = {symbol="MoveWindow", ret="bool", args={"i32","i32","i32","i32","bool"}, wrapper=function(l,p,x,y,w,h) return l:call("MoveWindow", "bool", {HWND_TYPE,"i32","i32","i32","i32","bool"}, p, x, y, w, h, true) end},
		SetFocus = {symbol="SetForegroundWindow", ret="bool", args={}},
		SetTopMost = {symbol="SetWindowPos", ret="bool", args={"bool"}, wrapper=function(l,p,e) return l:call("SetWindowPos", "bool", {HWND_TYPE,"i64","i32","i32","i32","i32","i32"}, p, e and -1 or -2, 0,0,0,0, 3) end},
		Click = {symbol="SetCursorPos", ret="void", args={"i32","i32"}, wrapper=function(l,p,x,y)
			local r = getRect(l, p); if not r then return end
			l:call("SetCursorPos", "bool", {"i32","i32"}, r.l+x, r.t+y)
			l:call("mouse_event", "void", {"i32","i32","i32","i32","u64"}, 2, 0, 0, 0, 0)
			l:call("mouse_event", "void", {"i32","i32","i32","i32","u64"}, 4, 0, 0, 0, 0)
		end},
		Close = {symbol="PostMessageA", ret="bool", args={"i32","i32","i32"}, wrapper=function(l,p) return l:call("PostMessageA", "bool", {HWND_TYPE,"i32","i32","i32"}, p, 16, 0, 0) end}
	},
	
	Events = {Closed=true, Moved=true, Resized=true},
	
	Static = {
		Alert = {
			symbol="MessageBoxA", ret="i32", args={"u64","pointer","pointer","i32"},
			wrapper = function(lib, _, a1, a2, a3, a4)
				local p, txt, tit, typ = (type(a1)=="table" and a2 or a1), (type(a1)=="table" and a3 or a2), (type(a1)=="table" and a4 or a3), (type(a1)=="table" and nil or a4)
				local bT = ffi.buffer(#tostring(txt or "Alert")+1); bT:writeString(0, tostring(txt or "Alert"))
				local bC = ffi.buffer(#tostring(tit or "Lune")+1); bC:writeString(0, tostring(tit or "Lune"))
				return lib:call("MessageBoxA", "i32", {"u64","pointer","pointer","i32"}, (type(p)=="number" and p or 0), bT.ptr, bC.ptr, (typ or 0)+0x40000)
			end
		},
		_EnumWindows = {symbol="EnumWindows", ret="i32", args={"pointer","i32"}}
	}
})

WindowImpl.Enums = Enums or {}

-- ============================================================
-- 3. LÓGICA DE INJEÇÃO (CORRIGIDA)
-- ============================================================
-- Função local que roda a lógica de monitoramento
local function startMonitoring(self, rate)
	if self._monitoring then return end
	self._monitoring = true
	task.spawn(function()
		local lastRect = {x=self.X, y=self.Y, w=self.Width, h=self.Height}
		while self._monitoring and not self._destroyed do
			local exists = self._lib:call("IsWindow", "bool", {HWND_TYPE}, self._ptr)
			if not exists then self.Closed:Fire(); self:Destroy(); break end
			
			local cx, cy, cw, ch = self.X, self.Y, self.Width, self.Height
			if cx ~= lastRect.x or cy ~= lastRect.y then self.Moved:Fire(cx, cy); lastRect.x, lastRect.y = cx, cy end
			if cw ~= lastRect.w or ch ~= lastRect.h then self.Resized:Fire(cw, ch); lastRect.w, lastRect.h = cw, ch end
			task.wait(rate or 0.1)
		end
	end)
end

-- Função para injetar métodos extras na instância
local function injectExtras(instance)
	if not instance then return nil end
	
	-- Injeta EnableMonitoring
	function instance:EnableMonitoring(rate)
		startMonitoring(self, rate)
	end

	return instance
end

-- Sobrescreve construtores para aplicar a injeção
local OriginalNew = WindowImpl.new
local OriginalFromPtr = WindowImpl.fromPointer

WindowImpl.new = function(...) return injectExtras(OriginalNew(...)) end
WindowImpl.fromPointer = function(...) return injectExtras(OriginalFromPtr(...)) end

function WindowImpl.AlertAsync(text, title, typeBitmask)
	local alertInst = { Response = Signal.new(), _task = nil }
	
	alertInst._task = task.spawn(function()
		-- CORREÇÃO CRÍTICA AQUI:
		-- Esperamos um frame para garantir que o 'Connect' no main.luau
		-- rodou ANTES da gente travar o processo com o MessageBox.
		task.wait() 
		
		local rID = WindowImpl.Alert(0, text, title, typeBitmask)
		
		-- Agora sim, disparamos (e o Connect já vai estar pronto pra ouvir)
		local btnName = Enums.MessageBox.Button[rID] or "Unknown"
		alertInst.Response:Fire(btnName, rID)
	end)
	
	return alertInst
end

function WindowImpl.GetWindows()
	local w = {}
	local cb = ffi.callback(function(h) table.insert(w, WindowImpl.fromPointer(h)); return 1 end, "i32", {"u64","i32"})
	local l = ffi.open("user32.dll")
	l:call("EnumWindows", "i32", {"pointer","i32"}, cb.ptr, 0)
	return w
end

function WindowImpl.GetFocusedWindow()
	local l = ffi.open("user32.dll")
	return WindowImpl.fromPointer(l:call("GetForegroundWindow", HWND_TYPE, {}))
end

return WindowImpl :: {
	new: (cls: string?, title: string?) -> Window?,
	fromPointer: (ptr: any) -> Window,
	GetWindows: () -> {Window},
	GetFocusedWindow: () -> Window,
	Alert: (hwnd: number, text: string, title: string, type: number) -> number,
	AlertAsync: (text: string, title: string?, type: number?) -> AlertInstance,
	Enums: typeof(Enums)
}