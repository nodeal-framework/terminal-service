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
	Implements the `memory` command: Shows server memory usage (Luau managed
	heap).
]=]

return {
	Name = "memory",
	Permission = "Moderator",
	Aliases = { "mem" },
	Description = "Shows server memory usage (Luau managed heap)",
	--[=[
		Shows server memory usage (Luau managed heap).

		@param context The command context.
		@return A status message when the command succeeds.
	]=]
	Run = function(context)
		local ok, kbytes = pcall(gcinfo)
		if not ok then
			return "Memory info unavailable in this environment"
		end
		return string.format("Memory: %d KB (%.2f MB)", kbytes, kbytes / 1024)
	end,
}
