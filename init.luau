-- init.luau - Ponto de entrada do módulo windows-service
local ffi = require("@lune/ffi")
local WindowClass = require("@windows-service/WindowClass")
local Enums = require("@windows-service/Enums")
local Types = require("@windows-service/Types")
local injectExtras = require("@windows-service/InstanceMethods")
local injectStatics = require("@windows-service/StaticMethods")

-- Cache de DLLs (aberto uma vez)
local shell32 = ffi.open("shell32.dll")

-- Injeta métodos estáticos
injectStatics(WindowClass)

-- Wrapper para injetar métodos de instância
local OriginalNew = WindowClass.new
local OriginalFromPtr = WindowClass.fromPointer

WindowClass.new = function(...)
	return injectExtras(OriginalNew(...), WindowClass)
end

WindowClass.fromPointer = function(...)
	return injectExtras(OriginalFromPtr(...), WindowClass)
end

-- Anexa Enums
WindowClass.Enums = Enums

-- ===== NOVAS FUNÇÕES ESTILO ROBLOX =====

-- Find: retorna array com todas as janelas que correspondem ao filtro
function WindowClass.Find(titleOrFilter)
	if type(titleOrFilter) == "string" then
		local pattern = titleOrFilter:lower()
		return WindowClass.GetWindows(function(w)
			return w.Title:lower():find(pattern, 1, true) ~= nil
		end)
	elseif type(titleOrFilter) == "function" then
		return WindowClass.GetWindows(titleOrFilter)
	else
		return WindowClass.GetWindows()
	end
end

-- FindFirst: retorna primeira janela que corresponde ao filtro
function WindowClass.FindFirst(titleOrFilter)
	local results = WindowClass.Find(titleOrFilter)
	return results[1]
end

-- FindFirstOfClass: busca por ClassName
function WindowClass.FindFirstOfClass(className)
	local pattern = className:lower()
	return WindowClass.FindFirst(function(w)
		return w.ClassName:lower():find(pattern, 1, true) ~= nil
	end)
end

-- Spawn: inicia processo e retorna janela principal EXATA (por HWND)
function WindowClass.Spawn(command, timeout)
	-- Extrai nome do executável para filtrar
	local exeName = command:match("([^/\\]+)%.exe") or command:match("([^/\\]+)$") or command

	-- Captura todos HWNDs visíveis ANTES de abrir
	local existingHwnds = {}
	for _, w in ipairs(WindowClass.GetWindows()) do
		if w.IsVisible then
			existingHwnds[w._ptr] = true
		end
	end

	-- Abre via ShellExecuteA (funciona com apps single-instance)
	local cmdBuf = ffi.buffer(#command + 1)
	cmdBuf:writeString(0, command)
	local opBuf = ffi.buffer(5)
	opBuf:writeString(0, "open")
	shell32:call(
		"ShellExecuteA",
		"i64",
		{ "u64", "pointer", "pointer", "pointer", "pointer", "i32" },
		0,
		opBuf.ptr,
		cmdBuf.ptr,
		ffi.null,
		ffi.null,
		1
	)

	-- Aguarda nova janela aparecer (HWND que não existia antes)
	local maxTime = timeout or 10
	local start = os.clock()

	while (os.clock() - start) < maxTime do
		local windows = WindowClass.GetWindows(function(w)
			return w.IsVisible
				and w.ProcessName
				and w.ProcessName:lower():find(exeName:lower(), 1, true) ~= nil
				and not existingHwnds[w._ptr]
		end)
		if #windows > 0 then
			return windows[1]
		end
	end

	return nil
end

-- SpawnAsync: não bloqueia
function WindowClass.SpawnAsync(command, timeout)
	local task = require("@lune/task")
	local result = { window = nil, ready = false }
	task.spawn(function()
		result.window = WindowClass.Spawn(command, timeout)
		result.ready = true
	end)
	return result
end

return WindowClass :: Types.WindowModule
