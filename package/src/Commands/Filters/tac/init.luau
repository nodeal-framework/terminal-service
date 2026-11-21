--[[
    © 2026 Nodeal Package. All rights reserved.

    This source code is open-source and free for modification and use in your projects.
    However, you may not sell, sublicense, or distribute this framework (or 
    any rebranded version of it) as a standalone product.

    Any public use or redistribution of this module requires this header 
    to remain intact in the source code. For the complete license terms, 
    please visit: https://www.nodeal.dev/license
]]

local Getopt = require(script.Parent.Parent.Parent.Parent.Classes.Getopt)
local Text = require(script.Parent.Parent.Parent.Parent.Classes.Text)

return {
	Name = "tac",
	Permission = "Any",
	Description = "Concatenate and print stdin in reverse line order",
	Args = {},
	Run = function(context)
		local options, operands, err = Getopt.parse(context.Args, "bs:", {
			before = "b",
			separator = "s",
		})

		if err then
			context:Error(`tac: {err}`, 2)
			return ""
		end

		if #operands > 0 then
			context:Error(`tac: {operands[1]}: No such file or directory`, 2)
			return ""
		end

		local input = context:GetInput()
		local separator = options.s or "\n"

		local pieces = {}
		if separator == "\n" then
			pieces = Text.lines(input)
		else
			local start = 1
			while start <= #input do
				local index = string.find(input, separator, start, true)
				if not index then
					table.insert(pieces, string.sub(input, start))
					break
				end
				table.insert(pieces, string.sub(input, start, index - 1))
				start = index + #separator
			end
		end

		local out = {}
		for i = #pieces, 1, -1 do
			table.insert(out, pieces[i])
		end
		return table.concat(out, separator)
	end,
}
