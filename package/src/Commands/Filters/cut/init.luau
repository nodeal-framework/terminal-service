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
	Name = "cut",
	Permission = "Any",
	Description = "Remove sections from each line of stdin",
	Args = {},
	Run = function(context)
		local options, operands, err = Getopt.parse(context.Args, "b:c:d:f:s", {
			bytes = "b",
			characters = "c",
			delimiter = "d",
			fields = "f",
			["only-delimited"] = "s",
			complement = true,
			["output-delimiter"] = "output_delimiter",
		})

		if err then
			context:Error(`cut: {err}`, 2)
			return ""
		end

		if #operands > 0 then
			context:Error(`cut: {operands[1]}: No such file or directory`, 2)
			return ""
		end

		local spec = options.c or options.b or options.f
		if not spec then
			context:Error("cut: you must specify a list of bytes, characters, or fields", 2)
			return ""
		end

		local ranges, rangeErr = Text.selectRange(spec)
		if not ranges then
			context:Error(`cut: {rangeErr}`, 2)
			return ""
		end

		local complement = options.complement == true
		local outputDelimiter = options["output-delimiter"]
		local delimiter = options.d or "\t"
		local fieldMode = options.f ~= nil
		local onlyDelimited = options.s == true

		local out = {}

		for _, line in Text.lines(context:GetInput()) do
			if fieldMode then
				if not string.find(line, delimiter, 1, true) then
					if not onlyDelimited then
						table.insert(out, line)
					end
					continue
				end

				local fields = string.split(line, delimiter)
				local selected = {}
				for index, value in fields do
					local include = Text.inRanges(index, ranges)
					if complement then include = not include end
					if include then table.insert(selected, value) end
				end
				table.insert(out, table.concat(selected, outputDelimiter or delimiter))
			else
				local selected = {}
				for index = 1, #line do
					local include = Text.inRanges(index, ranges)
					if complement then include = not include end
					if include then table.insert(selected, string.sub(line, index, index)) end
				end
				table.insert(out, table.concat(selected))
			end
		end

		return table.concat(out, "\n")
	end,
}
