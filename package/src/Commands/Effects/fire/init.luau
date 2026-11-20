return {
	Name = "fire",
	Description = "Adds fire to a player",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player" }
	},
	Run = function(context, target: Player)
		if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			local s = target.Character.HumanoidRootPart:FindFirstChild("AdminFire")
			if not s then
				s = Instance.new("Fire")
				s.Name = "AdminFire"
				s.Parent = target.Character.HumanoidRootPart
			end
			return `Added fire to {target.Name}`
		end
		context:Error(`Could not add fire to {target.Name}`)
	end
}
