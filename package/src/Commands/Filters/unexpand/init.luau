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
	Name = "unexpand",
	Permission = "Any",
	Description = "Convert leading spaces to tabs",
	Args = {},
	Run = function(context)
		local options, operands, err = Getopt.parse(context.Args, "at:", {
			all = "a",
			tabs = "t",
		})

		if err then
			context:Error(`unexpand: {err}`, 2)
			return ""
		end

		if #operands > 0 then
			context:Error(`unexpand: {operands[1]}: No such file or directory`, 2)
			return ""
		end

		local tabwidth = tonumber(options.t) or 8
		local out = {}

		for _, line in Text.lines(context:GetInput()) do
			local result = {}
			local column = 0
			local i = 1

			while i <= #line do
				local c = string.sub(line, i, i)
				if c == " " then
					local spaces = string.match(string.sub(line, i), "^ +")
					local count = #spaces
					if options.a or column == 0 then
						while count >= tabwidth - (column % tabwidth) do
							local needed = tabwidth - (column % tabwidth)
							table.insert(result, "\t")
							column += needed
							count -= needed
						end
					end
					if count > 0 then
						table.insert(result, string.rep(" ", count))
						column += count
					end
					i += #spaces
				else
					table.insert(result, c)
					column += 1
					i += 1
				end
			end

			table.insert(out, table.concat(result))
		end

		return table.concat(out, "\n")
	end,
}
