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
	Implements the `refresh` command: Respawns a player and teleports them back
	to their previous position.
]=]

return {
	Name = "refresh",
	Aliases = { "rf" },
	Permission = "Admin",
	Description = "Respawns a player and teleports them back to their previous position",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player to refresh" },
	},
	--[=[
		Respawns a player and teleports them back to their previous position.

		@param context The command context.
		@param target Player to refresh
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player)
		local char = target.Character
		if not char or not char:FindFirstChild("HumanoidRootPart") then
			target:LoadCharacterAsync()
			char = target.CharacterAdded:Wait()
		end

		local position = char.HumanoidRootPart.CFrame
		target:LoadCharacterAsync()
		target.CharacterAdded:Once(function(newChar)
			if newChar:FindFirstChild("HumanoidRootPart") then
				newChar.HumanoidRootPart.CFrame = position
			end
		end)
		return `Refreshing {target.Name}`
	end,
}
