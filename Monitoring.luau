-- Monitoring.luau - Lógica de monitoramento de eventos
local task = require("@lune/task")
local Enums = require("@windows-service/Enums")

local HWND_TYPE = "u64"

local Monitoring = {}

function Monitoring.startMonitoring(instance, rate)
	-- A verificação de _monitoring já é feita pelo ffi-like-roblox

	task.spawn(function()
		local last = { x = instance.X, y = instance.Y, w = instance.Width, h = instance.Height }
		local currentStyle = instance._lib:call("GetWindowLongA", "i32", { HWND_TYPE, "i32" }, instance._ptr, -16)
		local lastIsMin = bit32.band(currentStyle, Enums.WindowStyle.WS_MINIMIZE) ~= 0
		local lastIsMax = bit32.band(currentStyle, Enums.WindowStyle.WS_MAXIMIZE) ~= 0

		while instance._monitoring and not instance._destroyed do
			local exists = instance._lib:call("IsWindow", "bool", { HWND_TYPE }, instance._ptr)
			if not exists then
				instance.Closed:Fire()
				instance.Changed:Fire("Closed", true)
				instance:Destroy()
				break
			end

			local cx, cy, cw, ch = instance.X, instance.Y, instance.Width, instance.Height
			if cx ~= last.x or cy ~= last.y then
				instance.Moved:Fire(cx, cy)
				instance.Changed:Fire("Position", { X = cx, Y = cy })
				last.x, last.y = cx, cy
			end
			if cw ~= last.w or ch ~= last.h then
				instance.Resized:Fire(cw, ch)
				instance.Changed:Fire("Size", { Width = cw, Height = ch })
				last.w, last.h = cw, ch
			end

			local style = instance._lib:call("GetWindowLongA", "i32", { HWND_TYPE, "i32" }, instance._ptr, -16)
			local isMin = bit32.band(style, Enums.WindowStyle.WS_MINIMIZE) ~= 0
			local isMax = bit32.band(style, Enums.WindowStyle.WS_MAXIMIZE) ~= 0

			if isMin ~= lastIsMin then
				if isMin then
					instance.Minimized:Fire()
					instance.Changed:Fire("State", "Minimized")
				elseif not isMax then
					instance.Restored:Fire()
					instance.Changed:Fire("State", "Restored")
				end
				lastIsMin = isMin
			end

			if isMax ~= lastIsMax then
				if isMax then
					instance.Maximized:Fire()
					instance.Changed:Fire("State", "Maximized")
				elseif not isMin then
					instance.Restored:Fire()
					instance.Changed:Fire("State", "Restored")
				end
				lastIsMax = isMax
			end

			task.wait(rate or 0.1)
		end
	end)
end

return Monitoring
