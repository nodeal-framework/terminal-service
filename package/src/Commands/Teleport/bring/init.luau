return {
	Name = "bring",
	Description = "Teleports a player to you",
	Permission = "Moderator",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player to bring" }
	},
	Run = function(context, target: Player)
		local executor = context.Executor
		if executor.Character and executor.Character:FindFirstChild("HumanoidRootPart") then
			if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
				context.Terminal:SavePos(target)
				target.Character.HumanoidRootPart.CFrame = executor.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -5)
				return `Brought {target.Name}`
			end
		end
		context:Error("Could not bring player")
	end
}
