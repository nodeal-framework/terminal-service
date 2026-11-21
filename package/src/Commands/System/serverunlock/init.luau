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
	Implements the `serverunlock` command: Unlocks the server to allow new
	joiners.
]=]

return {
	Name = "serverunlock",
	Aliases = { "unslock" },
	Permission = "Admin",
	Description = "Unlocks the server to allow new joiners",
	--[=[
		Unlocks the server to allow new joiners.

		@param context The command context.
		@return A status message when the command succeeds.
	]=]
	Run = function(context)
		local TerminalService = context.Terminal
		TerminalService.Locked = false

		if TerminalService.LockConnection then
			TerminalService.LockConnection:Disconnect()
			TerminalService.LockConnection = nil
		end

		return "Server unlocked. New players can join."
	end,
}
