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
	Name = "column",
	Permission = "Any",
	Description = "Format stdin into columns",
	Args = {},
	Run = function(context)
		local options, operands, err = Getopt.parse(context.Args, "ts:o:c:x", {
			table = "t",
			separator = "s",
			output_separator = "o",
			width = "c",
			fill_rows = "x",
		})

		if err then
			context:Error(`column: {err}`, 2)
			return ""
		end

		if #operands > 0 then
			context:Error(`column: {operands[1]}: No such file or directory`, 2)
			return ""
		end

		local input = options.s
		local output = options.o or "  "
		local rows = {}

		for _, line in Text.lines(context:GetInput()) do
			local fields = if input then string.split(line, input) else (function()
				local list = {}
				for field in string.gmatch(line, "%S+") do table.insert(list, field) end
				return list
			end)()
			table.insert(rows, fields)
		end

		if not options.t then
			return context:GetInput()
		end

		local widths = {}
		for _, fields in rows do
			for index, field in fields do
				widths[index] = math.max(widths[index] or 0, #field)
			end
		end

		local out = {}
		for _, fields in rows do
			local parts = {}
			for index, field in fields do
				if index == #fields then
					table.insert(parts, field)
				else
					table.insert(parts, field .. string.rep(" ", (widths[index] or #field) - #field))
				end
			end
			table.insert(out, table.concat(parts, output))
		end

		return table.concat(out, "\n")
	end,
}
