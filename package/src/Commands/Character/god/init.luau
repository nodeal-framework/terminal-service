return {
	Name = "god",
	Description = "Makes a player invincible",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player to make invincible" }
	},
	Run = function(context, target: Player)
		if target.Character and target.Character:FindFirstChild("Humanoid") then
			target.Character.Humanoid.MaxHealth = math.huge
			target.Character.Humanoid.Health = math.huge
			return `Made {target.Name} invincible`
		end
		context:Error(`Could not god {target.Name}`)
	end
}
