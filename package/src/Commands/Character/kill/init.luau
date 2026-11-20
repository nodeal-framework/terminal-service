return {
	Name = "kill",
	Description = "Kills a player",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player to kill" }
	},
	Run = function(context, target: Player)
		if target.Character and target.Character:FindFirstChild("Humanoid") then
			target.Character.Humanoid.Health = 0
			return `Killed {target.Name}`
		end
		context:Error(`Could not kill {target.Name}`)
	end
}