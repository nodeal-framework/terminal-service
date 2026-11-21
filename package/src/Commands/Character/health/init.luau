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
	Implements the `health` command: Sets a player's current Health.
]=]

return {
	Name = "health",
	Permission = "Admin",
	Description = "Sets a player's current Health",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
		{
			Name = "Health",
			Type = "number",
			Description = "Health value (cannot exceed MaxHealth unless god)",
		},
	},
	--[=[
		Sets a player's current Health.

		@param context The command context.
		@param target Player
		@param health Health value (cannot exceed MaxHealth unless god)
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target, health)
		if not target.Character or not target.Character:FindFirstChildOfClass("Humanoid") then
			context:Error(`{target.Name} has no Humanoid`)
			return
		end
		target.Character.Humanoid.Health = health
		return `Set {target.Name}'s Health to {health}`
	end,
}
