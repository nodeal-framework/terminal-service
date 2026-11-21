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
	Implements the `maxhealth` command: Sets a player's MaxHealth.
]=]

return {
	Name = "maxhealth",
	Aliases = { "maxhp" },
	Permission = "Admin",
	Description = "Sets a player's MaxHealth",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
		{ Name = "MaxHealth", Type = "number", Description = "Maximum health value" },
	},
	--[=[
		Sets a player's MaxHealth.

		@param context The command context.
		@param target Player
		@param maximumHealth The maximum health to apply.
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target, maximumHealth)
		if not target.Character or not target.Character:FindFirstChildOfClass("Humanoid") then
			context:Error(`{target.Name} has no Humanoid`)
			return
		end
		local hum = target.Character.Humanoid
		hum.MaxHealth = maximumHealth
		if hum.Health > maximumHealth then
			hum.Health = maximumHealth
		end
		return `Set {target.Name}'s MaxHealth to {maximumHealth}`
	end,
}
