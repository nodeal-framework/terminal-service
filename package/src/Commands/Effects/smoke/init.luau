return {
	Name = "smoke",
	Description = "Adds smoke to a player",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player" }
	},
	Run = function(context, target: Player)
		if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			local s = target.Character.HumanoidRootPart:FindFirstChild("AdminSmoke")
			if not s then
				s = Instance.new("Smoke")
				s.Name = "AdminSmoke"
				s.Parent = target.Character.HumanoidRootPart
			end
			return `Added smoke to {target.Name}`
		end
		context:Error(`Could not add smoke to {target.Name}`)
	end
}
