return {
	Name = "sit",
	Permission = "Admin",
	Description = "Forces a player to sit",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player to sit" }
	},
	Run = function(context, target: Player)
		if target.Character and target.Character:FindFirstChildOfClass("Humanoid") then
			target.Character.Humanoid.Sit = true
			return `{target.Name} is now sitting`
		end
		context:Error(`Could not sit {target.Name}`)
	end
}
