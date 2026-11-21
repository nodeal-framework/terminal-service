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
	Implements the `setgravity` command: Adjusts Workspace.Gravity.
]=]

return {
	Name = "setgravity",
	Aliases = { "grav" },
	Permission = "Admin",
	Description = "Adjusts Workspace.Gravity",
	Args = {
		{
			Name = "Value",
			Type = "number",
			Description = "Gravity (Roblox default: 196.2)",
			Default = 196.2,
		},
	},
	--[=[
		Adjusts Workspace.Gravity.

		@param context The command context.
		@param value Gravity (Roblox default: 196.2)
		@return A status message when the command succeeds.
	]=]
	Run = function(context, value: number)
		workspace.Gravity = value
		return `Workspace gravity set to {value}`
	end,
}
