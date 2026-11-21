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
	Implements the `setcolor` command: Sets the global ambient lighting color.
]=]

local Lighting = game:GetService("Lighting")

return {
	Name = "setcolor",
	Permission = "Admin",
	Description = "Sets the global ambient lighting color",
	Args = {
		{ Name = "Color", Type = "Color3", Description = "The ambient color to set" },
	},
	--[=[
		Sets the global ambient lighting color.

		@param context The command context.
		@param color The ambient color to set
		@return A status message when the command succeeds.
	]=]
	Run = function(context, color: Color3)
		Lighting.Ambient = color
		Lighting.OutdoorAmbient = color
		local hex = "#" .. color:ToHex()
		return `Set the ambient color to {hex}`
	end,
}
