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
	Implements the `day` command: Sets the time of day to noon (12:00:00).
]=]

return {
	Name = "day",
	Permission = "Admin",
	Description = "Sets the time of day to noon (12:00:00)",
	--[=[
		Sets the time of day to noon (12:00:00).

		@param context The command context.
		@return A status message when the command succeeds.
	]=]
	Run = function(context)
		game:GetService("Lighting").TimeOfDay = "12:00:00"
		return "Time of day set to noon (12:00)"
	end,
}
