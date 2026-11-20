return {
	Name = "unfreeze",
	Description = "Unfreezes a player",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player to unfreeze" }
	},
	Run = function(context, target: Player)
		if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			target.Character.HumanoidRootPart.Anchored = false
			return `Unfroze {target.Name}`
		end
		context:Error(`Could not unfreeze {target.Name}`)
	end
}
