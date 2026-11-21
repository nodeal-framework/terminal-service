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
	Implements the `globalambient` command: Sets the Lighting.OutdoorAmbient
	color globally.
]=]

return {
	Name = "globalambient",
	Aliases = { "gambient" },
	Permission = "Admin",
	Description = "Sets the Lighting.OutdoorAmbient color globally",
	Args = {
		{ Name = "Color", Type = "Color3", Description = "Outdoor ambient color" },
	},
	--[=[
		Sets the Lighting.OutdoorAmbient color globally.

		@param context The command context.
		@param color Outdoor ambient color
		@return A status message when the command succeeds.
	]=]
	Run = function(context, color: Color3)
		game:GetService("Lighting").OutdoorAmbient = color
		return `Outdoor ambient set to {color:ToHex()}`
	end,
}
