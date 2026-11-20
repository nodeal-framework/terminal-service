return {
	Name = "char",
	Aliases = { "copyappearance" },
	Permission = "Admin",
	Description = "Clones the appearance of one player onto another via HumanoidDescription. Persists across respawns",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player receiving the appearance" },
		{ Name = "Source", Type = "Player", Description = "Player to copy from" }
	},
	Run = function(context, target: Player, source: Player)
		local sourceHumanoid = source.Character and source.Character:FindFirstChildOfClass("Humanoid")
		if not sourceHumanoid then
			context:Error(`{source.Name} has no Humanoid`)
			return
		end

		local desc = sourceHumanoid:GetAppliedDescription()
		local TerminalService = context.Terminal

		local function applyToChar(char: Model)
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			if not humanoid then
				humanoid = char:WaitForChild("Humanoid", 5)
			end
			if humanoid then
				humanoid:ApplyDescription(desc)
			end
		end

		if target.Character then applyToChar(target.Character) end

		if not TerminalService.CloneConns then TerminalService.CloneConns = {} end
		if TerminalService.CloneConns[target.UserId] then
			TerminalService.CloneConns[target.UserId]:Disconnect()
		end
		TerminalService.CloneConns[target.UserId] = target.CharacterAdded:Connect(applyToChar)

		return `Cloned appearance from {source.Name} to {target.Name}`
	end
}
