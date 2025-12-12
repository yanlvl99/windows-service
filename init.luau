-- init.luau - Ponto de entrada do módulo windows-service
local WindowClass = require("@windows-service/WindowClass")
local Enums = require("@windows-service/Enums")
local Types = require("@windows-service/Types")
local injectExtras = require("@windows-service/InstanceMethods")
local injectStatics = require("@windows-service/StaticMethods")

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

return WindowClass :: Types.WindowModule
