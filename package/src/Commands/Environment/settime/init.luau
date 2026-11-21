--[[
    © 2026 Nodeal Package. All rights reserved.

    This source code is open-source and free for modification and use in your projects.
    However, you may not sell, sublicense, or distribute this framework (or 
    any rebranded version of it) as a standalone product.

    Any public use or redistribution of this module requires this header 
    to remain intact in the source code. For the complete license terms, 
    please visit: https://www.nodeal.dev/license
]]

--[=[
	Implements the `settime` command: Sets the time of day.
]=]

local Lighting = game:GetService("Lighting")

return {
	Name = "settime",
	Aliases = { "timeofday" },
	Description = "Sets the time of day",
	Permission = "Admin",
	Args = {
		{ Name = "Time", Type = "time", Description = "Time of day" },
	},
	--[=[
		Sets the time of day.

		@param context The command context.
		@param timeString The time to parse.
		@return A status message when the command succeeds.
	]=]
	Run = function(context, timeString: string)
		Lighting.TimeOfDay = timeString
		return `Set time of day to {timeString}`
	end,
}
