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
	Implements the `setteam` command: Assigns a player to a Team. Uses the team
	type with custom UI for selection.
]=]

return {
	Name = "setteam",
	Permission = "Admin",
	Description = "Assigns a player to a Team. Uses the team type with custom UI for selection",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
		{ Name = "Team", Type = "Team", Description = "Team to assign" },
	},
	--[=[
		Assigns a player to a Team. Uses the team type with custom UI for selection.

		@param context The command context.
		@param target Player
		@param team Team to assign
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target, team)
		target.Team = team
		return `Set {target.Name}'s team to {team.Name}`
	end,
}
