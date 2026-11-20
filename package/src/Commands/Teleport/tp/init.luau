return {
	Name = "tp",
	Permission = "Admin",
	Description = "Teleports Subject to Destination's position",
	Args = {
		{ Name = "Subject", Type = "Player", Description = "Player to teleport" },
		{ Name = "Destination", Type = "Player", Description = "Destination player" }
	},
	Run = function(context, subject: Player, destination: Player)
		if subject.Character and subject.Character:FindFirstChild("HumanoidRootPart")
			and destination.Character and destination.Character:FindFirstChild("HumanoidRootPart") then
			context.Terminal:SavePos(subject)
			subject.Character.HumanoidRootPart.CFrame = destination.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -3)
			return `Teleported {subject.Name} to {destination.Name}`
		end
		context:Error("Could not teleport (missing character or HumanoidRootPart)")
	end
}
