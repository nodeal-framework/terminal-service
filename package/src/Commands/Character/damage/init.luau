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
	Implements the `damage` command: Inflicts a specified amount of damage on a
	player.
]=]

return {
	Name = "damage",
	Aliases = { "dmg" },
	Permission = "Admin",
	Description = "Inflicts a specified amount of damage on a player",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player to damage" },
		{ Name = "Amount", Type = "number", Description = "Damage amount" },
	},
	--[=[
		Inflicts a specified amount of damage on a player.

		@param context The command context.
		@param target Player to damage
		@param amount Damage amount
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player, amount: number)
		if target.Character and target.Character:FindFirstChildOfClass("Humanoid") then
			target.Character.Humanoid:TakeDamage(amount)
			return `Dealt {amount} damage to {target.Name}`
		end
		context:Error(`Could not damage {target.Name}`)
	end,
}
