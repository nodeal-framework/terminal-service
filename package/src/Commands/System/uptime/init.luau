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
	Implements the `uptime` command: Shows how long the server has been running.
]=]

return {
	Name = "uptime",
	Permission = "Any",
	Description = "Shows how long the server has been running",
	--[=[
		Shows how long the server has been running.

		@param context The command context.
		@return A status message when the command succeeds.
	]=]
	Run = function(context)
		local s = context.Terminal:GetUptime()
		local days = math.floor(s / 86400)
		local hrs = math.floor((s % 86400) / 3600)
		local mins = math.floor((s % 3600) / 60)
		local secs = math.floor(s % 60)
		return string.format("Uptime: %dd %02dh %02dm %02ds", days, hrs, mins, secs)
	end,
}
