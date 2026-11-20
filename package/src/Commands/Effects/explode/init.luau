return {
	Name = "explode",
	Description = "Creates an explosion at a player",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player" }
	},
	Run = function(context, target: Player)
		if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			local e = Instance.new("Explosion")
			e.Position = target.Character.HumanoidRootPart.Position
			e.Parent = workspace
			return `Exploded {target.Name}`
		end
		context:Error(`Could not explode {target.Name}`)
	end
}
