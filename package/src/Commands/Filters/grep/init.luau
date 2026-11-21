--[[
    © 2026 Nodeal Package. All rights reserved.

    This source code is open-source and free for modification and use in your projects.
    However, you may not sell, sublicense, or distribute this framework (or 
    any rebranded version of it) as a standalone product.

    Any public use or redistribution of this module requires this header 
    to remain intact in the source code. For the complete license terms, 
    please visit: https://www.nodeal.dev/license
]]

local Grep = require(script.Parent.Parent.Parent.Parent.Classes.Grep)

return {
	Name = "grep",
	Permission = "Any",
	Aliases = { "match" },
	Description = "Filter stdin: keep lines matching a POSIX extended regular expression",
	Args = {},
	Run = function(context)
		local code, output, err = Grep.run(context, context.Args, false)
		context:SetCode(code)
		if err ~= "" then
			context:Error(err, code)
		end
		return output
	end,
}
