return {
	Name = "tppos",
	Permission = "Admin",
	Description = "Teleports a player to specific coordinates (X, Y, Z)",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
		{ Name = "Position", Type = "Vector3", Description = "Target coordinates" }
	},
	Run = function(context, target: Player, position: Vector3)
		if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			context.Terminal:SavePos(target)
			target.Character.HumanoidRootPart.CFrame = CFrame.new(position)
			return `Teleported {target.Name} to {position.X}, {position.Y}, {position.Z}`
		end
		context:Error(`Could not teleport {target.Name}`)
	end
}
