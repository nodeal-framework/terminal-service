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
	Implements the `jump` command: Sets a player's jump power.
]=]

return {
	Name = "jump",
	Aliases = { "jumppower", "jp" },
	Description = "Sets a player's jump power",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player to set the jump power of" },
		{ Name = "Power", Type = "number", Description = "The jump power" },
	},
	--[=[
		Sets a player's jump power.

		@param context The command context.
		@param target The player to set the jump power of
		@param power The jump power
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player, power: number)
		if target.Character and target.Character:FindFirstChild("Humanoid") then
			target.Character.Humanoid.UseJumpPower = true
			target.Character.Humanoid.JumpPower = power
			return `Set {target.Name}'s jump power to {power}`
		end
		context:Error(`Could not set jump power for {target.Name}`)
	end,
}
