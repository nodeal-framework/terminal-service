return {
	Name = "coords",
	Aliases = { "pos", "position", "whereami" },
	Description = "Shows the executor's current character coordinates",
	Run = function(context)
		local p = context.Executor
		if not p or not p.Character or not p.Character:FindFirstChild("HumanoidRootPart") then
			return "No character to locate"
		end
		local pos = p.Character.HumanoidRootPart.Position
		return string.format("Position: X=%.2f Y=%.2f Z=%.2f", pos.X, pos.Y, pos.Z)
	end
}
