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
	Implements the `nl` command: Number lines of stdin.
]=]

local Getopt = require(script.Parent.Parent.Parent.Parent.Classes.Getopt)
local Text = require(script.Parent.Parent.Parent.Parent.Classes.Text)

return {
	Name = "nl",
	Permission = "Any",
	Description = "Number lines of stdin",
	Args = {},
	--[=[
		Number lines of stdin.

		@param context The command context.
		@return A status message when the command succeeds.
	]=]
	Run = function(context)
		local options, operands, errorValue = Getopt.parse(context.Args, "b:n:w:s:v:i:d:", {
			body_numbering = "b",
			number_format = "n",
			number_width = "w",
			separator = "s",
			starting_line_number = "v",
			line_increment = "i",
			section_delimiter = "d",
		})

		if errorValue then
			context:Error(`nl: {errorValue}`, 2)
			return ""
		end

		if #operands > 0 then
			context:Error(`nl: {operands[1]}: No such file or directory`, 2)
			return ""
		end

		local body = options.b or "t"
		local format = options.n or "rn"
		local width = tonumber(options.w) or 6
		local separator = options.s or "\t"
		local number = tonumber(options.v) or 1
		local increment = tonumber(options.i) or 1

		local out = {}
		for _, line in Text.lines(context:GetInput()) do
			local numberThis = body == "a" or (body == "t" and line ~= "")
			if numberThis then
				local text = tostring(number)
				local formatted
				if format == "ln" then
					formatted = text .. string.rep(" ", math.max(0, width - #text))
				elseif format == "rz" then
					formatted = string.rep("0", math.max(0, width - #text)) .. text
				else
					formatted = string.rep(" ", math.max(0, width - #text)) .. text
				end
				table.insert(out, formatted .. separator .. line)
				number += increment
			else
				table.insert(out, string.rep(" ", width) .. separator .. line)
			end
		end

		return table.concat(out, "\n")
	end,
}
