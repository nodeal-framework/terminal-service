return {
	Name = "stand",
	Permission = "Admin",
	Description = "Forces a player to stand up",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player to stand" }
	},
	Run = function(context, target: Player)
		if target.Character and target.Character:FindFirstChildOfClass("Humanoid") then
			local hum = target.Character.Humanoid
			hum.Sit = false
			hum.Jump = true
			return `{target.Name} is now standing`
		end
		context:Error(`Could not stand {target.Name}`)
	end
}
