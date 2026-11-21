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
	Implements the `fog` command: Sets fog color, start, and end distances at
	once.
]=]

return {
	Name = "fog",
	Permission = "Admin",
	Description = "Sets fog color, start, and end distances at once",
	Args = {
		{ Name = "Color", Type = "Color3", Description = "Fog color" },
		{ Name = "Start", Type = "number", Description = "Fog start distance" },
		{ Name = "Finish", Type = "number", Description = "Fog end distance" },
	},
	--[=[
		Sets fog color, start, and end distances at once.

		@param context The command context.
		@param color Fog color
		@param start Fog start distance
		@param finish Fog end distance
		@return A status message when the command succeeds.
	]=]
	Run = function(context, color: Color3, start: number, finish: number)
		local Lighting = game:GetService("Lighting")
		Lighting.FogColor = color
		Lighting.FogStart = start
		Lighting.FogEnd = finish
		return `Fog set: color {color:ToHex()}, start {start}, end {finish}`
	end,
}
