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
	Implements the `upper` command: Convert stdin to UPPERCASE.
]=]

return {
	Name = "upper",
	Permission = "Any",
	Description = "Convert stdin to UPPERCASE",
	--[=[
		Convert stdin to UPPERCASE.

		@param context The command context.
		@return A status message when the command succeeds.
	]=]
	Run = function(context)
		return string.upper(context:GetInput())
	end,
}
