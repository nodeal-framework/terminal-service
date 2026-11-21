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
	Name = "wc",
	Permission = "Any",
	Aliases = { "count" },
	Description = "Count lines, words, characters and bytes in stdin",
	Args = {},
	Run = function(context)
		local options, operands, err = Getopt.parse(context.Args, "lwcmL", {
			lines = "l",
			words = "w",
			bytes = "c",
			chars = "m",
			max_line_length = "L",
		})

		if err then
			context:Error(`wc: {err}`, 2)
			return ""
		end

		if #operands > 0 then
			context:Error(`wc: {operands[1]}: No such file or directory`, 2)
			return ""
		end

		local input = context:GetInput()
		local lines = Text.lines(input)

		local lineCount = #lines
		local wordCount = 0
		for _ in string.gmatch(input, "%S+") do
			wordCount += 1
		end

		local byteCount = #input
		local charCount = utf8.len(input) or byteCount
		local maxLength = 0
		for _, line in lines do
			maxLength = math.max(maxLength, utf8.len(line) or #line)
		end

		local any = options.l or options.w or options.c or options.m or options.L
		local wantLines = options.l or not any
		local wantWords = options.w or not any
		local wantBytes = options.c or not any
		local wantChars = options.m == true
		local wantMax = options.L == true

		local parts = {}
		if wantLines then table.insert(parts, tostring(lineCount)) end
		if wantWords then table.insert(parts, tostring(wordCount)) end
		if wantChars then
			table.insert(parts, tostring(charCount))
		elseif wantBytes then
			table.insert(parts, tostring(byteCount))
		end
		if wantMax then table.insert(parts, tostring(maxLength)) end

		if #parts == 1 then
			return parts[1]
		end

		local out = {}
		for _, part in parts do
			table.insert(out, string.rep(" ", math.max(0, 7 - #part)) .. part)
		end
		return table.concat(out, " ")
	end,
}
