-- InstanceMethods.luau - Métodos injetados em cada instância de Window
local ffi = require("@lune/ffi")
local task = require("@lune/task")
local Monitoring = require("@windows-service/Monitoring")

local HWND_TYPE = "u64"

return function(instance, WindowImpl)
	if not instance then
		return nil
	end

	function instance:EnableMonitoring(rate)
		Monitoring.startMonitoring(self, rate)
	end

	function instance:StopMonitoring()
		self._monitoring = false
	end

	function instance:WaitForClose(timeout)
		local start = os.clock()
		while self._lib:call("IsWindow", "bool", { HWND_TYPE }, self._ptr) do
			if timeout and (os.clock() - start) >= timeout then
				return false
			end
			task.wait(0.1)
		end
		return true
	end

	function instance:GetChildren()
		local children = {}
		local cb = ffi.callback(function(h)
			table.insert(children, WindowImpl.fromPointer(h))
			return 1
		end, "i32", { HWND_TYPE, "i64" })
		self._lib:call("EnumChildWindows", "bool", { HWND_TYPE, "pointer", "i64" }, self._ptr, cb.ptr, 0)
		return children
	end

	function instance:GetParent()
		local h = self._lib:call("GetParent", HWND_TYPE, { HWND_TYPE }, self._ptr)
		return h ~= 0 and WindowImpl.fromPointer(h) or nil
	end

	-- Shake: treme a janela
	function instance:Shake(intensity, duration)
		local int = intensity or 10
		local dur = duration or 0.3
		local ox, oy = self.X, self.Y
		local steps = math.floor(dur / 0.03)
		for _ = 1, steps do
			self.X = ox + math.random(-int, int)
			self.Y = oy + math.random(-int, int)
			task.wait(0.03)
		end
		self.X, self.Y = ox, oy
	end

	-- Center: centraliza na tela
	function instance:Center()
		local screenW = self._lib:call("GetSystemMetrics", "i32", { "i32" }, 0) -- SM_CXSCREEN
		local screenH = self._lib:call("GetSystemMetrics", "i32", { "i32" }, 1) -- SM_CYSCREEN
		local newX = math.floor((screenW - self.Width) / 2)
		local newY = math.floor((screenH - self.Height) / 2)
		self:Move(newX, newY, self.Width, self.Height)
	end

	-- Kill: termina o processo da janela
	function instance:Kill()
		local kernel32 = ffi.open("kernel32.dll")
		local handle = kernel32:call("OpenProcess", "pointer", { "u32", "bool", "u32" }, 1, false, self.ProcessId)
		if handle and not ffi.isNull(handle) then
			kernel32:call("TerminateProcess", "bool", { "pointer", "u32" }, handle, 0)
			kernel32:call("CloseHandle", "bool", { "pointer" }, handle)
			return true
		end
		return false
	end

	-- FindChild: busca filho por ClassName ou parte do título
	function instance:FindChild(classOrTitle)
		for _, child in self:GetChildren() do
			if child.ClassName:find(classOrTitle, 1, true) or child.Title:find(classOrTitle, 1, true) then
				return child
			end
		end
		return nil
	end

	-- DragTo: arrasta a janela animadamente para nova posição
	function instance:DragTo(targetX, targetY, duration)
		local dur = duration or 0.3
		local startX, startY = self.X, self.Y
		local steps = math.max(1, math.floor(dur / 0.016))
		for i = 1, steps do
			local t = i / steps
			self.X = math.floor(startX + (targetX - startX) * t)
			self.Y = math.floor(startY + (targetY - startY) * t)
			task.wait(0.016)
		end
	end

	-- Detach: remove do pai (torna janela de nível superior)
	function instance:Detach()
		self._lib:call("SetParent", "u64", { "u64", "u64" }, self._ptr, 0)
	end

	-- Pin: fixa janela sempre visível + transparente (clique atravessa)
	function instance:Pin(clickThrough)
		self.AlwaysOnTop = true
		if clickThrough then
			local ex = self.ExStyle
			self.ExStyle = bit32.bor(ex, 0x80000, 0x20) -- WS_EX_LAYERED + WS_EX_TRANSPARENT
			self.Transparency = 0.1
		end
	end

	-- Unpin: remove fixação
	function instance:Unpin()
		self.AlwaysOnTop = false
		local ex = self.ExStyle
		self.ExStyle = bit32.band(ex, bit32.bnot(0x20)) -- remove WS_EX_TRANSPARENT
	end

	-- GetAllChildren: retorna todos os filhos recursivamente
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

	-- === Métodos de teclado para janela específica (via PostMessage) ===
	local WM_KEYDOWN = 0x0100
	local WM_KEYUP = 0x0101

	-- Pressiona tecla na janela
	function instance:PressKey(vk)
		self._lib:call("PostMessageA", "bool", { "u64", "u32", "u64", "i64" }, self._ptr, WM_KEYDOWN, vk, 0)
	end

	-- Solta tecla na janela
	function instance:ReleaseKey(vk)
		self._lib:call("PostMessageA", "bool", { "u64", "u32", "u64", "i64" }, self._ptr, WM_KEYUP, vk, 0)
	end

	-- Tap na janela
	function instance:Tap(vk)
		self:PressKey(vk)
		self:ReleaseKey(vk)
	end

	-- Hotkey na janela - foca e usa input global para compatibilidade
	function instance:Hotkey(...)
		local keys = { ... }
		-- Foca a janela primeiro
		self._lib:call("SetForegroundWindow", "bool", { "u64" }, self._ptr)
		task.wait(0.05)
		-- Usa keybd_event global (mais compatível com apps modernos)
		for _, vk in ipairs(keys) do
			self._lib:call("keybd_event", "void", { "u8", "u8", "u32", "u64" }, vk, 0, 0, 0)
		end
		for i = #keys, 1, -1 do
			self._lib:call("keybd_event", "void", { "u8", "u8", "u32", "u64" }, keys[i], 0, 2, 0)
		end
	end

	-- Write em background via WM_CHAR (suporta Unicode)
	function instance:Write(text)
		local WM_CHAR = 0x0102
		-- Decodifica UTF-8 para codepoints
		local i = 1
		while i <= #text do
			local byte = string.byte(text, i)
			local codepoint, skip
			if byte < 128 then
				codepoint = byte
				skip = 1
			elseif byte < 224 then
				codepoint =
					bit32.bor(bit32.lshift(bit32.band(byte, 0x1F), 6), bit32.band(string.byte(text, i + 1), 0x3F))
				skip = 2
			elseif byte < 240 then
				codepoint = bit32.bor(
					bit32.lshift(bit32.band(byte, 0x0F), 12),
					bit32.lshift(bit32.band(string.byte(text, i + 1), 0x3F), 6),
					bit32.band(string.byte(text, i + 2), 0x3F)
				)
				skip = 3
			else
				codepoint = bit32.bor(
					bit32.lshift(bit32.band(byte, 0x07), 18),
					bit32.lshift(bit32.band(string.byte(text, i + 1), 0x3F), 12),
					bit32.lshift(bit32.band(string.byte(text, i + 2), 0x3F), 6),
					bit32.band(string.byte(text, i + 3), 0x3F)
				)
				skip = 4
			end
			-- Para emojis (>0xFFFF), envia como surrogate pairs
			if codepoint > 0xFFFF then
				local s = codepoint - 0x10000
				self._lib:call(
					"PostMessageW",
					"bool",
					{ "u64", "u32", "u64", "i64" },
					self._ptr,
					WM_CHAR,
					0xD800 + bit32.rshift(s, 10),
					0
				)
				self._lib:call(
					"PostMessageW",
					"bool",
					{ "u64", "u32", "u64", "i64" },
					self._ptr,
					WM_CHAR,
					0xDC00 + bit32.band(s, 0x3FF),
					0
				)
			else
				self._lib:call("PostMessageW", "bool", { "u64", "u32", "u64", "i64" }, self._ptr, WM_CHAR, codepoint, 0)
			end
			i = i + skip
		end
	end

	return instance
end
