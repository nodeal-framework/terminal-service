return {
	Name = "refresh",
	Aliases = { "rf" },
	Permission = "Admin",
	Description = "Respawns a player and teleports them back to their previous position",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player to refresh" }
	},
	Run = function(context, target: Player)
		local char = target.Character
		if not char or not char:FindFirstChild("HumanoidRootPart") then
			target:LoadCharacterAsync()
			char = target.CharacterAdded:Wait()
		end

		local pos = char.HumanoidRootPart.CFrame
		target:LoadCharacterAsync()
		target.CharacterAdded:Once(function(newChar)
			if newChar:FindFirstChild("HumanoidRootPart") then
				newChar.HumanoidRootPart.CFrame = pos
			end
		end)
		return `Refreshing {target.Name}`
	end
}
