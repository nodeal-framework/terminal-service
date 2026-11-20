return {
	Name = "heal",
	Description = "Heals a player",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player to heal" },
		{ Name = "Amount", Type = "number", Description = "Amount to heal to", Default = -1 }
	},
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
	end
}
