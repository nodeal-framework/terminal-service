return {
	Name = "up",
	Permission = "Admin",
	Description = "Raises a player by N studs on the Y axis",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
		{ Name = "Studs", Type = "number", Description = "Studs to raise", Default = 10 }
	},
	Run = function(context, target: Player, studs: number)
		if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			target.Character.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame + Vector3.new(0, studs, 0)
			return `Raised {target.Name} by {studs} studs`
		end
		context:Error(`Could not raise {target.Name}`)
	end
}
