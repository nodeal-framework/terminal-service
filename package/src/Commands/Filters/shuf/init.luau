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
	Implements the `shuf` command: Shuffle lines of stdin or a numeric range.
]=]

local Getopt = require(script.Parent.Parent.Parent.Parent.Classes.Getopt)
local Text = require(script.Parent.Parent.Parent.Parent.Classes.Text)

return {
	Name = "shuf",
	Permission = "Any",
	Aliases = { "randomize", "shuffle" },
	Description = "Shuffle lines of stdin or a numeric range",
	Args = {},
	--[=[
		Shuffle lines of stdin or a numeric range.

		@param context The command context.
		@return A status message when the command succeeds.
	]=]
	Run = function(context)
		local options, operands, errorValue = Getopt.parse(context.Args, "n:ri:e:z", {
			head_count = "n",
			["repeat"] = "r",
			input_range = "i",
			echo = "e",
			zero_terminated = "z",
		})

		if errorValue then
			context:Error(`shuf: {errorValue}`, 2)
			return ""
		end

		local items = {}

		if options.i then
			local first, last = string.match(options.i, "^([%+%-]?%d+)%-([%+%-]?%d+)$")
			if not first then
				context:Error(`shuf: invalid input range: '{options.i}'`, 1)
				return ""
			end
			local a, b = tonumber(first), tonumber(last)
			for value = a, b do
				table.insert(items, tostring(value))
			end
		elseif options.e then
			for _, value in operands do
				table.insert(items, value)
			end
		elseif #operands > 0 then
			context:Error(`shuf: {operands[1]}: No such file or directory`, 1)
			return ""
		else
			items = Text.lines(context:GetInput())
		end

		--[=[
			Shuffles a list in place.

			@param list The list to process.
		]=]
		local function shuffle(list)
			for i = #list, 2, -1 do
				local j = math.random(1, i)
				list[i], list[j] = list[j], list[i]
			end
		end

		if options.r then
			local count = tonumber(options.n) or #items
			local out = {}
			if #items == 0 then
				return ""
			end
			for _ = 1, count do
				table.insert(out, items[math.random(1, #items)])
			end
			return table.concat(out, "\n")
		end

		shuffle(items)

		local count = tonumber(options.n)
		if count and count < #items then
			local trimmed = {}
			for i = 1, math.max(0, count) do
				table.insert(trimmed, items[i])
			end
			items = trimmed
		end

		return table.concat(items, if options.z then "\0" else "\n")
	end,
}
