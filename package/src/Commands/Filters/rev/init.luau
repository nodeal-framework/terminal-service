--[[
    © 2026 Nodeal Package. All rights reserved.

    This source code is open-source and free for modification and use in your projects.
    However, you may not sell, sublicense, or distribute this framework (or 
    any rebranded version of it) as a standalone product.

    Any public use or redistribution of this module requires this header 
    to remain intact in the source code. For the complete license terms, 
    please visit: https://www.nodeal.dev/license
]]

local Text = require(script.Parent.Parent.Parent.Parent.Classes.Text)

return {
	Name = "rev",
	Permission = "Any",
	Description = "Reverse the characters of each line of stdin",
	Args = {},
	Run = function(context)
		local out = {}
		for _, line in Text.lines(context:GetInput()) do
			local chars = {}
			for i = #line, 1, -1 do
				table.insert(chars, string.sub(line, i, i))
			end
			table.insert(out, table.concat(chars))
		end
		return table.concat(out, "\n")
	end,
}
