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
	Implements the `speed` command: Sets a player's walkspeed.
]=]

return {
	Name = "speed",
	Aliases = { "walkspeed", "ws" },
	Description = "Sets a player's walkspeed",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player to set the speed of" },
		{ Name = "Speed", Type = "number", Description = "The walkspeed" },
	},
	--[=[
		Sets a player's walkspeed.

		@param context The command context.
		@param target The player to set the speed of
		@param speed The walkspeed
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player, speed: number)
		if target.Character and target.Character:FindFirstChild("Humanoid") then
			target.Character.Humanoid.WalkSpeed = speed
			return `Set {target.Name}'s walkspeed to {speed}`
		end
		context:Error(`Could not set speed for {target.Name}`)
	end,
}
