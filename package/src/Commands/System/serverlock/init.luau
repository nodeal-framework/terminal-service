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
	Implements the `serverlock` command: Locks the server so new players cannot
	join.
]=]

local Players = game:GetService("Players")

return {
	Name = "serverlock",
	Aliases = { "slock" },
	Permission = "Admin",
	Description = "Locks the server so new players cannot join",
	--[=[
		Locks the server so new players cannot join.

		@param context The command context.
		@return A status message when the command succeeds.
	]=]
	Run = function(context)
		local TerminalService = context.Terminal
		if TerminalService.Locked then
			return "Server is already locked"
		end

		TerminalService.Locked = true
		TerminalService.LockConnection = Players.PlayerAdded:Connect(function(p)
			if TerminalService.Locked then
				p:Kick("Server is currently locked. Try again later.")
			end
		end)

		return "Server locked. New joiners will be rejected."
	end,
}
