--[[
    © 2026 Nodeal Package. All rights reserved.

    This source code is open-source and free for modification and use in your projects.
    However, you may not sell, sublicense, or distribute this framework (or 
    any rebranded version of it) as a standalone product.

    Any public use or redistribution of this module requires this header 
    to remain intact in the source code. For the complete license terms, 
    please visit: https://www.nodeal.dev/license
]]

--[=[
	Implements the `char` command: Clones the appearance of one player onto
	another via HumanoidDescription. Persists across respawns.
]=]

return {
	Name = "char",
	Aliases = { "copyappearance" },
	Permission = "Admin",
	Description = "Clones the appearance of one player onto another via HumanoidDescription. Persists "
		.. "across respawns",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player receiving the appearance" },
		{ Name = "Source", Type = "Player", Description = "Player to copy from" },
	},
	--[=[
		Clones the appearance of one player onto another via HumanoidDescription.
		Persists across respawns.

		@param context The command context.
		@param target Player receiving the appearance
		@param source Player to copy from
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player, source: Player)
		local sourceHumanoid = source.Character
			and source.Character:FindFirstChildOfClass("Humanoid")
		if not sourceHumanoid then
			context:Error(`{source.Name} has no Humanoid`)
			return
		end

		local description = sourceHumanoid:GetAppliedDescription()
		local TerminalService = context.Terminal

		--[=[
			Copies the appearance of the source character.

			@param char The character to inspect.
		]=]
		local function applyToChar(char: Model)
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			if not humanoid then
				humanoid = char:WaitForChild("Humanoid", 5)
			end
			if humanoid then
				humanoid:ApplyDescription(description)
			end
		end

		if target.Character then
			applyToChar(target.Character)
		end

		if not TerminalService.CloneConns then
			TerminalService.CloneConns = {}
		end
		if TerminalService.CloneConns[target.UserId] then
			TerminalService.CloneConns[target.UserId]:Disconnect()
		end
		TerminalService.CloneConns[target.UserId] = target.CharacterAdded:Connect(applyToChar)

		return `Cloned appearance from {source.Name} to {target.Name}`
	end,
}
