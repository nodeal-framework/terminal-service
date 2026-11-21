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
	Implements the `players` command: Lists all players in the server.
]=]

local Players = game:GetService("Players")

return {
	Name = "players",
	Description = "Lists all players in the server",
	Permission = "Any",
	Args = {},
	--[=[
		Lists all players in the server.

		@param context The command context.
		@return A status message when the command succeeds.
	]=]
	Run = function(context)
		local names = {}
		for _, p in Players:GetPlayers() do
			table.insert(names, p.Name)
		end
		if #names == 0 then
			return "No players found"
		end
		return table.concat(names, "\n")
	end,
}
