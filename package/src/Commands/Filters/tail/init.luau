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
	Implements the `tail` command: Output the last part of stdin (default: 10
	lines).
]=]

local Getopt = require(script.Parent.Parent.Parent.Parent.Classes.Getopt)
local Text = require(script.Parent.Parent.Parent.Parent.Classes.Text)

return {
	Name = "tail",
	Permission = "Any",
	Description = "Output the last part of stdin (default: 10 lines)",
	Args = {},
	--[=[
		Output the last part of stdin (default: 10 lines).

		@param context The command context.
		@return A status message when the command succeeds.
	]=]
	Run = function(context)
		local options, operands, errorValue = Getopt.parse(context.Args, "n:c:qvfz", {
			lines = "n",
			bytes = "c",
			quiet = "q",
			verbose = "v",
			follow = "f",
			zero_terminated = "z",
		})

		if errorValue then
			context:Error(`tail: {errorValue}`, 2)
			return ""
		end

		if #operands > 0 then
			context:Error(`tail: {operands[1]}: No such file or directory`, 2)
			return ""
		end

		if options.f then
			context:Error("tail: -f: there is no filesystem", 2)
			return ""
		end

		local input = context:GetInput()

		if options.c then
			local raw = options.c
			local fromStart = string.sub(raw, 1, 1) == "+"
			local count = Text.number(raw)
			if not count then
				context:Error(`tail: invalid number of bytes: '{raw}'`, 2)
				return ""
			end
			if fromStart then
				return string.sub(input, math.max(1, count))
			end
			if count >= 0 then
				return string.sub(input, math.max(1, #input - count + 1))
			end
			return string.sub(input, 1, math.max(0, #input + count))
		end

		local raw = options.n or "10"
		local fromLine = string.sub(raw, 1, 1) == "+"
		local count = Text.number(raw)
		if not count then
			context:Error(`tail: invalid number of lines: '{raw}'`, 2)
			return ""
		end

		local lines = Text.lines(input)

		if fromLine then
			local out = {}
			for i = math.max(1, count), #lines do
				table.insert(out, lines[i])
			end
			return table.concat(out, "\n")
		end

		if count < 0 then
			local out = {}
			for i = 1, math.max(0, #lines + count) do
				table.insert(out, lines[i])
			end
			return table.concat(out, "\n")
		end

		local start = math.max(1, #lines - count + 1)
		local out = {}
		for i = start, #lines do
			table.insert(out, lines[i])
		end
		return table.concat(out, "\n")
	end,
}
