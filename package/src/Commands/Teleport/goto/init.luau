return {
	Name = "goto",
	Description = "Teleports you to a player",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player to teleport to" }
	},
	Run = function(context, target: Player)
		local executor = context.Executor
		if executor.Character and executor.Character:FindFirstChild("HumanoidRootPart") then
			if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
				context.Terminal:SavePos(executor)
				executor.Character.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -5)
				return `Teleported to {target.Name}`
			end
		end
		context:Error("Could not teleport")
	end
}
