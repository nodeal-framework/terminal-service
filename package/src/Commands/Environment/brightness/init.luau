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
	Implements the `brightness` command: Adjusts the global Lighting Brightness.
]=]

return {
	Name = "brightness",
	Permission = "Admin",
	Description = "Adjusts the global Lighting Brightness",
	Args = {
		{ Name = "Value", Type = "number", Description = "Brightness value (default 2)" },
	},
	--[=[
		Adjusts the global Lighting Brightness.

		@param context The command context.
		@param value Brightness value (default 2)
		@return A status message when the command succeeds.
	]=]
	Run = function(context, value: number)
		game:GetService("Lighting").Brightness = value
		return `Brightness set to {value}`
	end,
}
