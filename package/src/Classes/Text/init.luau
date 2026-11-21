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
	Shared text helpers for the coreutils-style filter commands.
]=]

local Text = {}

--[=[
	Splits text into lines. A trailing newline does not create an extra empty line.
]=]
function Text.lines(input: string): { string }
	if input == "" then
		return {}
	end

	local out = {}
	local start = 1
	local len = #input

	while start <= len do
		local index = string.find(input, "\n", start, true)
		if not index then
			table.insert(out, string.sub(input, start))
			break
		end
		table.insert(out, string.sub(input, start, index - 1))
		start = index + 1
	end

	return out
end

function Text.join(lines: { string }): string
	return table.concat(lines, "\n")
end

--[=[
	Parses an integer, accepting a leading + or -.
]=]
function Text.number(value: string?): number?
	if value == nil then return nil end
	local text = string.match(value, "^%s*([%+%-]?%d+)%s*$")
	if not text then return nil end
	return tonumber(text)
end

--[=[
	Expands a cut-style selection list: "1", "1,3", "2-5", "1-3,7-".
]=]
function Text.selectRange(value: string): any
	local ranges = {}

	for piece in string.gmatch(value, "[^,]+") do
		local first, second = string.match(piece, "^(%d*)%-(%d*)$")
		if first then
			local a = if first == "" then 1 else tonumber(first)
			local b = if second == "" then math.huge else tonumber(second)
			if not a or not b or a < 1 or b < a then
				return nil, `invalid range '{piece}'`
			end
			table.insert(ranges, { a, b })
		else
			local number = tonumber(piece)
			if not number or number < 1 then
				return nil, `invalid range '{piece}'`
			end
			table.insert(ranges, { number, number })
		end
	end

	return ranges, nil
end

function Text.inRanges(index: number, ranges: { any }): boolean
	for _, range in ranges do
		if index >= range[1] and index <= range[2] then
			return true
		end
	end
	return false
end

--[=[
	Right-aligns a count the way wc does.
]=]
function Text.padCount(value: number, width: number): string
	local text = tostring(value)
	return string.rep(" ", math.max(0, width - #text)) .. text
end

return Text
