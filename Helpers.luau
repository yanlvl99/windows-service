-- Helpers.luau - Funções auxiliares para FFI
local ffi = require("@lune/ffi")

local HWND_TYPE = "u64"

local Helpers = {}

function Helpers.getRect(lib, hwnd)
	local b = ffi.buffer(16)
	if lib:call("GetWindowRect", "i32", { HWND_TYPE, "pointer" }, hwnd, b.ptr) == 0 then
		return nil
	end
	return { l = b:read(0, "i32"), t = b:read(4, "i32"), r = b:read(8, "i32"), b = b:read(12, "i32") }
end

function Helpers.getString(lib, func, hwnd)
	local b = ffi.buffer(512)
	lib:call(func, "i32", { HWND_TYPE, "pointer", "i32" }, hwnd, b.ptr, 512)
	return b:readString()
end

Helpers.HWND_TYPE = HWND_TYPE

return Helpers
