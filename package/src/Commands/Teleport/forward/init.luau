return {
	Name = "forward",
	Aliases = { "fwd" },
	Permission = "Admin",
	Description = "Pushes the player N studs forward along their HumanoidRootPart LookVector",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
		{ Name = "Studs", Type = "number", Description = "Studs forward", Default = 10 }
	},
	Run = function(context, target: Player, studs: number)
		if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			local hrp = target.Character.HumanoidRootPart
			hrp.CFrame = hrp.CFrame + hrp.CFrame.LookVector * studs
			return `Pushed {target.Name} forward by {studs} studs`
		end
		context:Error(`Could not push {target.Name}`)
	end
}
