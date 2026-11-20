return {
	Name = "ungod",
	Description = "Removes a player's invincibility",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player to ungod" }
	},
	Run = function(context, target: Player)
		if target.Character and target.Character:FindFirstChild("Humanoid") then
			target.Character.Humanoid.MaxHealth = 100
			if target.Character.Humanoid.Health > 100 then
				target.Character.Humanoid.Health = 100
			end
			return `Removed {target.Name}'s invincibility`
		end
		context:Error(`Could not ungod {target.Name}`)
	end
}
