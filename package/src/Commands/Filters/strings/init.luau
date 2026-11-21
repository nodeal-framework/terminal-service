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
	Implements the `strings` command: Print runs of printable characters from
	stdin.
]=]

local Getopt = require(script.Parent.Parent.Parent.Parent.Classes.Getopt)

return {
	Name = "strings",
	Permission = "Any",
	Description = "Print runs of printable characters from stdin",
	Args = {},
	--[=[
		Print runs of printable characters from stdin.

		@param context The command context.
		@return A status message when the command succeeds.
	]=]
	Run = function(context)
		local options, operands, errorValue = Getopt.parse(context.Args, "n:a", {
			minimum = "n",
			all = "a",
		})

		if errorValue then
			context:Error(`strings: {errorValue}`, 2)
			return ""
		end

		if #operands > 0 then
			context:Error(`strings: {operands[1]}: No such file or directory`, 2)
			return ""
		end

		local minimum = tonumber(options.n) or 4
		local input = context:GetInput()
		local out = {}
		local current = {}

		for i = 1, #input do
			local byte = string.byte(input, i) or 0
			local printable = byte == 9 or (byte >= 32 and byte < 127)
			if printable then
				table.insert(current, string.char(byte))
			else
				if #current >= minimum then
					table.insert(out, table.concat(current))
				end
				current = {}
			end
		end

		if #current >= minimum then
			table.insert(out, table.concat(current))
		end

		return table.concat(out, "\n")
	end,
}
