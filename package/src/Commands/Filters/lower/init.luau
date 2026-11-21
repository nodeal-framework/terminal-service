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
	Implements the `lower` command: Convert stdin to lowercase.
]=]

return {
	Name = "lower",
	Permission = "Any",
	Description = "Convert stdin to lowercase",
	--[=[
		Convert stdin to lowercase.

		@param context The command context.
		@return A status message when the command succeeds.
	]=]
	Run = function(context)
		return string.lower(context:GetInput())
	end,
}
