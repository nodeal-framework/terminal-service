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
	Implements the `god` command: Makes a player invincible.
]=]

return {
	Name = "god",
	Description = "Makes a player invincible",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player to make invincible" },
	},
	--[=[
		Makes a player invincible.

		@param context The command context.
		@param target The player to make invincible
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player)
		if target.Character and target.Character:FindFirstChild("Humanoid") then
			target.Character.Humanoid.MaxHealth = math.huge
			target.Character.Humanoid.Health = math.huge
			return `Made {target.Name} invincible`
		end
		context:Error(`Could not god {target.Name}`)
	end,
}
