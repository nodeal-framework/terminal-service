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
	Implements the `date` command: Shows the current server time.
]=]

return {
	Name = "date",
	Description = "Shows the current server time",
	Permission = "Any",
	Args = {},
	--[=[
		Shows the current server time.

		@param context The command context.
		@return A status message when the command succeeds.
	]=]
	Run = function(context)
		local t = os.time()
		local d = os.date("!*t", t)
		return string.format(
			"UTC Time: %04d-%02d-%02d %02d:%02d:%02d",
			d.year,
			d.month,
			d.day,
			d.hour,
			d.min,
			d.sec
		)
	end,
}
