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
	Implements the `heal` command: Heals a player.
]=]

return {
	Name = "heal",
	Description = "Heals a player",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player to heal" },
		{ Name = "Amount", Type = "number", Description = "Amount to heal to", Default = -1 },
	},
	--[=[
		Heals a player.

		@param context The command context.
		@param target The player to heal
		@param amount Amount to heal to
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player, amount: number)
		if target.Character and target.Character:FindFirstChild("Humanoid") then
			local humanoid = target.Character.Humanoid
			if amount == -1 then
				humanoid.Health = humanoid.MaxHealth
				return `Fully healed {target.Name}`
			else
				humanoid.Health = math.clamp(amount, 0, humanoid.MaxHealth)
				return `Healed {target.Name} to {amount}`
			end
		end
		context:Error(`Could not heal {target.Name}`)
	end,
}
