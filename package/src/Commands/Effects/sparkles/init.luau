return {
	Name = "sparkles",
	Description = "Adds sparkles to a player",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player" }
	},
	Run = function(context, target: Player)
		if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			local s = target.Character.HumanoidRootPart:FindFirstChild("AdminSparkles")
			if not s then
				s = Instance.new("Sparkles")
				s.Name = "AdminSparkles"
				s.Parent = target.Character.HumanoidRootPart
			end
			return `Added sparkles to {target.Name}`
		end
		context:Error(`Could not add sparkles to {target.Name}`)
	end
}
