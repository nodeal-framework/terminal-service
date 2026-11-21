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
	Implements the `shutdown` command: Kicks all players and shuts the server
	down.
]=]

local Players = game:GetService("Players")

return {
	Name = "shutdown",
	Permission = "Admin",
	Description = "Kicks all players and shuts the server down",
	Args = {
		{
			Name = "Reason",
			Type = "string",
			Description = "Kick reason (also saved)",
			Default = "Server shutting down",
		},
	},
	--[=[
		Kicks all players and shuts the server down.

		@param context The command context.
		@param reason Kick reason (also saved)
		@return A status message when the command succeeds.
	]=]
	Run = function(context, reason: string)
		for _, p in Players:GetPlayers() do
			p:Kick(reason)
		end
		task.delay(2, function()
			game:Shutdown()
		end)
		return `Shutting down: {reason}`
	end,
}
