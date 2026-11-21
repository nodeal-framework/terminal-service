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
	Implements the `ungod` command: Removes a player's invincibility.
]=]

return {
	Name = "ungod",
	Description = "Removes a player's invincibility",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player to ungod" },
	},
	--[=[
		Removes a player's invincibility.

		@param context The command context.
		@param target The player to ungod
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player)
		if target.Character and target.Character:FindFirstChild("Humanoid") then
			target.Character.Humanoid.MaxHealth = 100
			if target.Character.Humanoid.Health > 100 then
				target.Character.Humanoid.Health = 100
			end
			return `Removed {target.Name}'s invincibility`
		end
		context:Error(`Could not ungod {target.Name}`)
	end,
}
