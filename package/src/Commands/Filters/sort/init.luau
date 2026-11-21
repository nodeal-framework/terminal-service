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

local function splitFields(line: string, delimiter: string?): { string }
	if delimiter then
		return string.split(line, delimiter)
	end
	local fields = {}
	for field in string.gmatch(line, "%S+") do
		table.insert(fields, field)
	end
	return fields
end

local function humanNumber(text: string): number
	local number, suffix = string.match(text, "^%s*([%+%-]?%d+%.?%d*)([kKmMgGtTpPeE]?)")
	if not number then return 0 end
	local value = tonumber(number) or 0
	local multipliers = { k = 1e3, m = 1e6, g = 1e9, t = 1e12, p = 1e15, e = 1e18 }
	local key = string.lower(suffix)
	if multipliers[key] then
		value *= multipliers[key]
	end
	return value
end

return {
	Name = "sort",
	Permission = "Any",
	Description = "Sort lines of stdin (case-sensitive by default)",
	Args = {},
	Run = function(context)
		local options, operands, err = Getopt.parse(context.Args, "rnufbdMhVsk:t:cz", {
			reverse = "r",
			numeric_sort = "n",
			unique = "u",
			ignore_case = "f",
			ignore_leading_blanks = "b",
			dictionary_order = "d",
			month_sort = "M",
			human_numeric_sort = "h",
			version_sort = "V",
			stable = "s",
			key = "k",
			field_separator = "t",
			check = "c",
			zero_terminated = "z",
		})

		if err then
			context:Error(`sort: {err}`, 2)
			return ""
		end

		if #operands > 0 then
			context:Error(`sort: {operands[1]}: No such file or directory`, 2)
			return ""
		end

		local lines = Text.lines(context:GetInput())
		if #lines == 0 then
			return ""
		end

		local keySpec = options.k
		local delimiter = options.t
		local keyStart, keyEnd, keyNumeric, keyReverse, keyFold = nil, nil, false, false, false

		if keySpec then
			local startText, endText, flags = string.match(keySpec, "^(%d*%.?%d*),?(%d*%.?%d*)([nrf]*)")
			keyStart = tonumber((string.match(startText or "1", "^%d+") or "1"))
			keyEnd = tonumber((string.match(endText or "", "^%d+") or "")) or keyStart
			keyNumeric = string.find(flags or "", "n", 1, true) ~= nil
			keyReverse = string.find(flags or "", "r", 1, true) ~= nil
			keyFold = string.find(flags or "", "f", 1, true) ~= nil
		end

		local function normalized(value: string): string
			if options.b or (keySpec and string.find(keySpec, "b", 1, true)) then
				value = string.gsub(value, "^%s+", "")
			end
			if options.d then
				value = string.gsub(value, "[^%w%s]", "")
			end
			if options.f or keyFold then
				value = string.lower(value)
			end
			return value
		end

		local function keyOf(line: string): string
			if not keyStart then
				return normalized(line)
			end
			local fields = splitFields(line, delimiter)
			local startField = fields[keyStart] or ""
			if keyEnd and keyEnd > keyStart then
				local parts = {}
				for i = keyStart, keyEnd do
					if fields[i] then table.insert(parts, fields[i]) end
				end
				startField = table.concat(parts, delimiter or " ")
			end
			return normalized(startField)
		end

		table.sort(lines, function(a, b)
			local ka, kb = keyOf(a), keyOf(b)
			if options.n or keyNumeric then
				local na, nb = tonumber(ka), tonumber(kb)
				if na and nb then
					if na == nb then return a < b end
					local result = na < nb
					if options.r or keyReverse then result = not result end
					return result
				end
			elseif options.h then
				local na, nb = humanNumber(ka), humanNumber(kb)
				if na ~= nb then
					local result = na < nb
					if options.r or keyReverse then result = not result end
					return result
				end
			end

			if ka == kb then return a < b end
			local result = ka < kb
			if options.r or keyReverse then result = not result end
			return result
		end)

		if options.u then
			local unique = {}
			local last = nil
			for _, line in lines do
				local key = keyOf(line)
				if key ~= last then
					table.insert(unique, line)
					last = key
				end
			end
			lines = unique
		end

		if options.c then
			local sorted = true
			for i = 2, #lines do
				if keyOf(lines[i - 1]) > keyOf(lines[i]) then
					sorted = false
					break
				end
			end
			if not sorted then
				context:SetCode(1)
			end
			return ""
		end

		return table.concat(lines, if options.z then "\0" else "\n")
	end,
}
