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
	Implements the `platformstand` command: Toggles PlatformStand (Ragdoll) on a
	player.
]=]

return {
	Name = "platformstand",
	Aliases = { "platstand" },
	Permission = "Admin",
	Description = "Toggles PlatformStand (Ragdoll) on a player",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
		{
			Name = "State",
			Type = "boolean",
			Description = "True = enable, False = disable",
			Default = true,
		},
	},
	--[=[
		Toggles PlatformStand (Ragdoll) on a player.

		@param context The command context.
		@param target Player
		@param state True = enable, False = disable
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player, state: boolean)
		if target.Character and target.Character:FindFirstChildOfClass("Humanoid") then
			target.Character.Humanoid.PlatformStand = state
			return `{target.Name}: PlatformStand = {tostring(state)}`
		end
		context:Error(`Could not change PlatformStand for {target.Name}`)
	end,
}
