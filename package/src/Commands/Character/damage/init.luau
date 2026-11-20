return {
	Name = "damage",
	Aliases = { "dmg" },
	Permission = "Admin",
	Description = "Inflicts a specified amount of damage on a player",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player to damage" },
		{ Name = "Amount", Type = "number", Description = "Damage amount" }
	},
	Run = function(context, target: Player, amount: number)
		if target.Character and target.Character:FindFirstChildOfClass("Humanoid") then
			target.Character.Humanoid:TakeDamage(amount)
			return `Dealt {amount} damage to {target.Name}`
		end
		context:Error(`Could not damage {target.Name}`)
	end
}
