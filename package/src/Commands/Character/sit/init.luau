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
	Implements the `sit` command: Forces a player to sit.
]=]

return {
	Name = "sit",
	Permission = "Admin",
	Description = "Forces a player to sit",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player to sit" },
	},
	--[=[
		Forces a player to sit.

		@param context The command context.
		@param target Player to sit
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player)
		if target.Character and target.Character:FindFirstChildOfClass("Humanoid") then
			target.Character.Humanoid.Sit = true
			return `{target.Name} is now sitting`
		end
		context:Error(`Could not sit {target.Name}`)
	end,
}
