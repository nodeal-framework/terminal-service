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
	Implements the `kick` command: Kicks a player from the server.
]=]

return {
	Name = "kick",
	Description = "Kicks a player from the server",
	Permission = "Moderator",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player to kick" },
		{
			Name = "Reason",
			Type = "string",
			Description = "Reason for the kick",
			Default = "No reason",
		},
	},
	--[=[
		Kicks a player from the server.

		@param context The command context.
		@param target The player to kick
		@param reason Reason for the kick
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player, reason: string)
		target:Kick(reason)
		return `Kicked {target.Name} for: {reason}`
	end,
}
