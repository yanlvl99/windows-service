
local ffi = require("@lune/ffi")
local Signal = require("@signals-like-roblox")
local task = require("@lune/task")
local Enums = require("@windows-service/Enums")

local HWND_TYPE = "u64"

return function(WindowImpl)
	function WindowImpl.AlertAsync(text, title, typeBitmask)
		local alertInst = { Response = Signal.new(), _task = nil }
		alertInst._task = task.spawn(function()
			task.wait()
			local rID = WindowImpl.Alert(0, text, title, typeBitmask)
			alertInst.Response:Fire(Enums.MessageBox.Button[rID] or "Unknown", rID)
		end)
		return alertInst
	end

	function WindowImpl.GetWindows(filter)
		local w = {}
		local cb = ffi.callback(function(h)
			local win = WindowImpl.fromPointer(h)
			if not filter or filter(win) then
				table.insert(w, win)
			end
			return 1
		end, "i32", { "u64", "i32" })
		local l = ffi.open("user32.dll")
		l:call("EnumWindows", "i32", { "pointer", "i32" }, cb.ptr, 0)
		return w
	end

	function WindowImpl.GetFocusedWindow()
		local l = ffi.open("user32.dll")
		return WindowImpl.fromPointer(l:call("GetForegroundWindow", HWND_TYPE, {}))
	end

	function WindowImpl.GetDesktopWindow()
		local l = ffi.open("user32.dll")
		return WindowImpl.fromPointer(l:call("GetDesktopWindow", HWND_TYPE, {}))
	end

	function WindowImpl.FindByPid(pid)
		local results = {}
		local cb = ffi.callback(function(h)
			local b = ffi.buffer(4)
			local l = ffi.open("user32.dll")
			l:call("GetWindowThreadProcessId", "u32", { HWND_TYPE, "pointer" }, h, b.ptr)
			if b:read(0, "u32") == pid then
				table.insert(results, WindowImpl.fromPointer(h))
			end
			return 1
		end, "i32", { "u64", "i32" })
		local l = ffi.open("user32.dll")
		l:call("EnumWindows", "i32", { "pointer", "i32" }, cb.ptr, 0)
		return results
	end

	function WindowImpl.GetActiveWindow()
		local l = ffi.open("user32.dll")
		return WindowImpl.fromPointer(l:call("GetActiveWindow", HWND_TYPE, {}))
	end

	-- Espera uma janela aparecer (por título)
	function WindowImpl.WaitFor(title, timeout)
		local start = os.clock()
		local maxTime = timeout or 10
		while (os.clock() - start) < maxTime do
			local win = WindowImpl.new(nil, title)
			if win then
				return win
			end
			task.wait(0.1)
		end
		return nil
	end

	-- Posição atual do cursor
	function WindowImpl.GetCursorPosition()
		local l = ffi.open("user32.dll")
		local b = ffi.buffer(8)
		l:call("GetCursorPos", "bool", { "pointer" }, b.ptr)
		return { X = b:read(0, "i32"), Y = b:read(4, "i32") }
	end

	-- Move o cursor para posição específica
	function WindowImpl.SetCursorPosition(x, y)
		local l = ffi.open("user32.dll")
		l:call("SetCursorPos", "bool", { "i32", "i32" }, x, y)
	end

	-- Clique global (não em janela específica)
	function WindowImpl.GlobalClick(x, y, button)
		local l = ffi.open("user32.dll")
		l:call("SetCursorPos", "bool", { "i32", "i32" }, x, y)
		if button == "right" then
			l:call("mouse_event", "void", { "i32", "i32", "i32", "i32", "u64" }, 8, 0, 0, 0, 0) -- RIGHTDOWN
			l:call("mouse_event", "void", { "i32", "i32", "i32", "i32", "u64" }, 16, 0, 0, 0, 0) -- RIGHTUP
		else
			l:call("mouse_event", "void", { "i32", "i32", "i32", "i32", "u64" }, 2, 0, 0, 0, 0) -- LEFTDOWN
			l:call("mouse_event", "void", { "i32", "i32", "i32", "i32", "u64" }, 4, 0, 0, 0, 0) -- LEFTUP
		end
	end

	-- Retorna o PID de uma janela pelo título
	function WindowImpl.GetPidByTitle(title)
		local win = WindowImpl.new(nil, title)
		return win and win.ProcessId or nil
	end

	-- ===== FUNÇÕES DE TECLADO GLOBAL =====
	local user32 = ffi.open("user32.dll")

	-- Pressiona uma tecla (keydown)
	function WindowImpl.PressKey(vk)
		user32:call("keybd_event", "void", { "u8", "u8", "u32", "u64" }, vk, 0, 0, 0)
	end

	-- Solta uma tecla (keyup)
	function WindowImpl.ReleaseKey(vk)
		user32:call("keybd_event", "void", { "u8", "u8", "u32", "u64" }, vk, 0, 2, 0) -- KEYEVENTF_KEYUP = 2
	end

	-- Pressiona e solta uma tecla
	function WindowImpl.Tap(vk)
		WindowImpl.PressKey(vk)
		WindowImpl.ReleaseKey(vk)
	end

	-- Executa um atalho (ex: Ctrl+W, Ctrl+Shift+S)
	function WindowImpl.Hotkey(...)
		local keys = { ... }
		-- Pressiona todos
		for _, vk in ipairs(keys) do
			WindowImpl.PressKey(vk)
		end
		-- Solta na ordem inversa
		for i = #keys, 1, -1 do
			WindowImpl.ReleaseKey(keys[i])
		end
	end

	-- Digita texto globalmente com suporte a Unicode (acentos, emojis)
	function WindowImpl.Type(text)
		-- Converte string para codepoints UTF-8
		local codepoints = {}
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
			table.insert(codepoints, codepoint)
			i = i + skip
		end

		-- Envia cada codepoint via SendInput com KEYEVENTF_UNICODE
		-- Estrutura INPUT: type(4) + pad(4) + KEYBDINPUT(24) = 40 bytes (x64)
		-- KEYBDINPUT: wVk(2) + wScan(2) + dwFlags(4) + time(4) + pad(4) + dwExtraInfo(8)
		local inputSize = 40
		for _, cp in ipairs(codepoints) do
			-- Para emojis (>0xFFFF), usa surrogate pairs
			local chars = {}
			if cp > 0xFFFF then
				local s = cp - 0x10000
				table.insert(chars, 0xD800 + bit32.rshift(s, 10))
				table.insert(chars, 0xDC00 + bit32.band(s, 0x3FF))
			else
				table.insert(chars, cp)
			end

			for _, ch in ipairs(chars) do
				-- Keydown
				local buf = ffi.buffer(inputSize)
				buf:write(0, "u32", 1) -- INPUT_KEYBOARD
				buf:write(8, "u16", 0) -- wVk = 0
				buf:write(10, "u16", ch) -- wScan = unicode char
				buf:write(12, "u32", 4) -- KEYEVENTF_UNICODE = 4
				user32:call("SendInput", "u32", { "u32", "pointer", "i32" }, 1, buf.ptr, inputSize)

				-- Keyup
				buf:write(12, "u32", 6) -- KEYEVENTF_UNICODE | KEYEVENTF_KEYUP
				user32:call("SendInput", "u32", { "u32", "pointer", "i32" }, 1, buf.ptr, inputSize)
			end
		end
	end

	-- Verifica se uma tecla está pressionada
	function WindowImpl.IsKeyDown(vk)
		local state = user32:call("GetAsyncKeyState", "i16", { "i32" }, vk)
		return bit32.band(state, 0x8000) ~= 0
	end

	-- Espera uma tecla ser pressionada
	function WindowImpl.WaitForKey(vk, timeout)
		local start = os.clock()
		local maxTime = timeout or 30
		while (os.clock() - start) < maxTime do
			if WindowImpl.IsKeyDown(vk) then
				return true
			end
			task.wait(0.01)
		end
		return false
	end
end
