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
	Implements the `grepv` command: Filter stdin: keep lines NOT matching a
	regular expression (grep -v).
]=]

local Grep = require(script.Parent.Parent.Parent.Parent.Classes.Grep)

return {
	Name = "grepv",
	Permission = "Any",
	Aliases = { "invert" },
	Description = "Filter stdin: keep lines NOT matching a regular expression (grep -v)",
	Args = {},
	--[=[
		Filter stdin: keep lines NOT matching a regular expression (grep -v).

		@param context The command context.
		@return A status message when the command succeeds.
	]=]
	Run = function(context)
		local code, output, errorValue = Grep.run(context, context.Args, true)
		context:SetCode(code)
		if errorValue ~= "" then
			context:Error(errorValue, code)
		end
		return output
	end,
}
