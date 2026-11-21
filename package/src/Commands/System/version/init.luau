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
	Implements the `version` command: Shows game and TerminalService version
	info.
]=]

return {
	Name = "version",
	Permission = "Any",
	Aliases = { "ver" },
	Description = "Shows game and TerminalService version info",
	--[=[
		Shows game and TerminalService version info.

		@param context The command context.
		@return A status message when the command succeeds.
	]=]
	Run = function(context)
		return string.format(
			"PlaceVersion: %s | PlaceId: %d | TerminalService: 1.0.0",
			tostring(game.PlaceVersion),
			game.PlaceId
		)
	end,
}
