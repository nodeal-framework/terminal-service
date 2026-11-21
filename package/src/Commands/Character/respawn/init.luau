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
	Implements the `respawn` command: Respawns a player (kills and respawns them
	at SpawnLocation).
]=]

return {
	Name = "respawn",
	Permission = "Moderator",
	Description = "Respawns a player (kills and respawns them at SpawnLocation)",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player to respawn" },
	},
	--[=[
		Respawns a player (kills and respawns them at SpawnLocation).

		@param context The command context.
		@param target Player to respawn
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player)
		target:LoadCharacterAsync()
		return `Respawning {target.Name}`
	end,
}
