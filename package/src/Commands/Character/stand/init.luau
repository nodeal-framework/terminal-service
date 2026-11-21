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
	Implements the `stand` command: Forces a player to stand up.
]=]

return {
	Name = "stand",
	Permission = "Admin",
	Description = "Forces a player to stand up",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player to stand" },
	},
	--[=[
		Forces a player to stand up.

		@param context The command context.
		@param target Player to stand
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player)
		if target.Character and target.Character:FindFirstChildOfClass("Humanoid") then
			local hum = target.Character.Humanoid
			hum.Sit = false
			hum.Jump = true
			return `{target.Name} is now standing`
		end
		context:Error(`Could not stand {target.Name}`)
	end,
}
