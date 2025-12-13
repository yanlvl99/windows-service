-- InstanceMethods.luau - Métodos injetados em cada instância de Window
local ffi = require("@lune/ffi")
local task = require("@lune/task")
local Monitoring = require("@windows-service/Monitoring")
local Signal = require("@signals-like-roblox")

local HWND_TYPE = "u64"

-- Helper: polling até condição
local function waitUntil(checkFn, timeout)
	local start = os.clock()
	while not checkFn() do
		if timeout and (os.clock() - start) >= timeout then
			return false
		end
		task.wait(0.05)
	end
	return true
end

return function(instance, WindowImpl)
	if not instance then
		return nil
	end

	local lib, ptr = instance._lib, instance._ptr

	-- Lazy monitoring
	local function ensureMonitoring()
		if instance._monitoring or instance._destroyed then
			return
		end
		instance._monitoring = true
		Monitoring.startMonitoring(instance, 0.1)
	end

	-- Setup signals
	for _, name in ipairs({
		"Closed",
		"Moved",
		"Resized",
		"Minimized",
		"Maximized",
		"Restored",
		"Focused",
		"Unfocused",
		"Changed",
	}) do
		if instance[name] then
			instance[name]._onFirstConnect = ensureMonitoring
		end
	end

	-- ========== ACTIONS (propriedade + método) ==========
	-- win.Close:Wait() ou win:Close()

	instance.Close = Signal.newAction(function()
		lib:call("PostMessageA", "bool", { HWND_TYPE, "i32", "i32", "i32" }, ptr, 16, 0, 0)
	end, function(t)
		return waitUntil(function()
			return not lib:call("IsWindow", "bool", { HWND_TYPE }, ptr)
		end, t)
	end, ensureMonitoring)

	instance.Maximize = Signal.newAction(function()
		lib:call("ShowWindow", "bool", { HWND_TYPE, "i32" }, ptr, 3)
	end, function(t)
		return waitUntil(function()
			return instance.IsMaximized
		end, t)
	end, ensureMonitoring)

	instance.Minimize = Signal.newAction(function()
		lib:call("ShowWindow", "bool", { HWND_TYPE, "i32" }, ptr, 6)
	end, function(t)
		return waitUntil(function()
			return instance.IsMinimized
		end, t)
	end, ensureMonitoring)

	instance.Restore = Signal.newAction(function()
		lib:call("ShowWindow", "bool", { HWND_TYPE, "i32" }, ptr, 9)
	end, function(t)
		return waitUntil(function()
			return not instance.IsMinimized and not instance.IsMaximized
		end, t)
	end, ensureMonitoring)

	instance.Focus = Signal.newAction(function()
		lib:call("SetForegroundWindow", "bool", { HWND_TYPE }, ptr)
	end, function(t)
		return waitUntil(function()
			return instance.IsFocused
		end, t)
	end, ensureMonitoring)

	instance.Show = Signal.newAction(function()
		lib:call("ShowWindow", "bool", { HWND_TYPE, "i32" }, ptr, 1)
	end, function(t)
		return waitUntil(function()
			return instance.IsVisible
		end, t)
	end)

	instance.Hide = Signal.newAction(function()
		lib:call("ShowWindow", "bool", { HWND_TYPE, "i32" }, ptr, 0)
	end, function(t)
		return waitUntil(function()
			return not instance.IsVisible
		end, t)
	end)

	-- ========== MÉTODOS SIMPLES ==========

	function instance:EnableMonitoring(rate)
		Monitoring.startMonitoring(self, rate)
	end
	function instance:StopMonitoring()
		self._monitoring = false
	end

	function instance:GetChildren()
		local children = {}
		local cb = ffi.callback(function(h)
			table.insert(children, WindowImpl.fromPointer(h))
			return 1
		end, "i32", { HWND_TYPE, "i64" })
		lib:call("EnumChildWindows", "bool", { HWND_TYPE, "pointer", "i64" }, ptr, cb.ptr, 0)
		return children
	end

	function instance:GetParent()
		local h = lib:call("GetParent", HWND_TYPE, { HWND_TYPE }, ptr)
		return h ~= 0 and WindowImpl.fromPointer(h) or nil
	end

	function instance:GetAllChildren()
		local all = {}
		local function collect(win)
			for _, child in win:GetChildren() do
				table.insert(all, child)
				collect(child)
			end
		end
		collect(self)
		return all
	end

	function instance:FindChild(pattern)
		for _, child in self:GetChildren() do
			if child.ClassName:find(pattern, 1, true) or child.Title:find(pattern, 1, true) then
				return child
			end
		end
		return nil
	end

	function instance:Shake(intensity, duration)
		local int, dur = intensity or 10, duration or 0.3
		local ox, oy = self.X, self.Y
		for _ = 1, math.floor(dur / 0.03) do
			self.X, self.Y = ox + math.random(-int, int), oy + math.random(-int, int)
			task.wait(0.03)
		end
		self.X, self.Y = ox, oy
	end

	function instance:Center()
		local sw = lib:call("GetSystemMetrics", "i32", { "i32" }, 0)
		local sh = lib:call("GetSystemMetrics", "i32", { "i32" }, 1)
		self:Move(math.floor((sw - self.Width) / 2), math.floor((sh - self.Height) / 2), self.Width, self.Height)
	end

	function instance:Kill()
		local k32 = ffi.open("kernel32.dll")
		local h = k32:call("OpenProcess", "pointer", { "u32", "bool", "u32" }, 1, false, self.ProcessId)
		if h and not ffi.isNull(h) then
			k32:call("TerminateProcess", "bool", { "pointer", "u32" }, h, 0)
			k32:call("CloseHandle", "bool", { "pointer" }, h)
			return true
		end
		return false
	end

	function instance:DragTo(x, y, dur)
		dur = dur or 0.3
		local sx, sy, steps = self.X, self.Y, math.max(1, math.floor(dur / 0.016))
		for i = 1, steps do
			local t = i / steps
			self.X, self.Y = math.floor(sx + (x - sx) * t), math.floor(sy + (y - sy) * t)
			task.wait(0.016)
		end
	end

	function instance:Detach()
		lib:call("SetParent", "u64", { "u64", "u64" }, ptr, 0)
	end

	function instance:Pin(clickThrough)
		self.AlwaysOnTop = true
		if clickThrough then
			self.ExStyle = bit32.bor(self.ExStyle, 0x80000, 0x20)
			self.Transparency = 0.1
		end
	end

	function instance:Unpin()
		self.AlwaysOnTop = false
		self.ExStyle = bit32.band(self.ExStyle, bit32.bnot(0x20))
	end

	-- Teclado
	local WM_KEYDOWN, WM_KEYUP, WM_CHAR = 0x0100, 0x0101, 0x0102

	function instance:PressKey(vk)
		lib:call("PostMessageA", "bool", { "u64", "u32", "u64", "i64" }, ptr, WM_KEYDOWN, vk, 0)
	end
	function instance:ReleaseKey(vk)
		lib:call("PostMessageA", "bool", { "u64", "u32", "u64", "i64" }, ptr, WM_KEYUP, vk, 0)
	end
	function instance:Tap(vk)
		self:PressKey(vk)
		self:ReleaseKey(vk)
	end

	function instance:Hotkey(...)
		local keys = { ... }
		lib:call("SetForegroundWindow", "bool", { "u64" }, ptr)
		task.wait(0.05)
		for _, vk in ipairs(keys) do
			lib:call("keybd_event", "void", { "u8", "u8", "u32", "u64" }, vk, 0, 0, 0)
		end
		for i = #keys, 1, -1 do
			lib:call("keybd_event", "void", { "u8", "u8", "u32", "u64" }, keys[i], 0, 2, 0)
		end
	end

	function instance:Write(text)
		local i = 1
		while i <= #text do
			local b = string.byte(text, i)
			local cp, skip
			if b < 128 then
				cp, skip = b, 1
			elseif b < 224 then
				cp, skip =
					bit32.bor(bit32.lshift(bit32.band(b, 0x1F), 6), bit32.band(string.byte(text, i + 1), 0x3F)), 2
			elseif b < 240 then
				cp, skip =
					bit32.bor(
						bit32.lshift(bit32.band(b, 0x0F), 12),
						bit32.lshift(bit32.band(string.byte(text, i + 1), 0x3F), 6),
						bit32.band(string.byte(text, i + 2), 0x3F)
					),
					3
			else
				cp, skip =
					bit32.bor(
						bit32.lshift(bit32.band(b, 0x07), 18),
						bit32.lshift(bit32.band(string.byte(text, i + 1), 0x3F), 12),
						bit32.lshift(bit32.band(string.byte(text, i + 2), 0x3F), 6),
						bit32.band(string.byte(text, i + 3), 0x3F)
					),
					4
			end
			if cp > 0xFFFF then
				local s = cp - 0x10000
				lib:call(
					"PostMessageW",
					"bool",
					{ "u64", "u32", "u64", "i64" },
					ptr,
					WM_CHAR,
					0xD800 + bit32.rshift(s, 10),
					0
				)
				lib:call(
					"PostMessageW",
					"bool",
					{ "u64", "u32", "u64", "i64" },
					ptr,
					WM_CHAR,
					0xDC00 + bit32.band(s, 0x3FF),
					0
				)
			else
				lib:call("PostMessageW", "bool", { "u64", "u32", "u64", "i64" }, ptr, WM_CHAR, cp, 0)
			end
			i = i + skip
		end
	end

	return instance
end
