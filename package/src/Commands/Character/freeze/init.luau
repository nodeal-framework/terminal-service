return {
	Name = "freeze",
	Description = "Freezes a player in place",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player to freeze" }
	},
	Run = function(context, target: Player)
		if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			target.Character.HumanoidRootPart.Anchored = true
			return `Froze {target.Name}`
		end
		context:Error(`Could not freeze {target.Name}`)
	end
}
