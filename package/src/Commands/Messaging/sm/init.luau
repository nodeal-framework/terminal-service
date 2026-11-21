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
	Implements the `sm` command: Broadcasts a chat message from 'System' in the
	standard chat channels for all players.
]=]

local Players = game:GetService("Players")

return {
	Name = "sm",
	Aliases = { "system", "systemchat" },
	Permission = "Admin",
	Description = "Broadcasts a chat message from 'System' in the standard chat channels for all "
		.. "players",
	Args = {
		{ Name = "Message", Type = "string", Description = "Message text" },
	},
	--[=[
		Broadcasts a chat message from 'System' in the standard chat channels for
		all players.

		@param context The command context.
		@param message Message text
		@return A status message when the command succeeds.
	]=]
	Run = function(context, message: string)
		for _, p in Players:GetPlayers() do
			context.Terminal:SendSystemChat(p, message)
		end
		return `System: {message}`
	end,
}
