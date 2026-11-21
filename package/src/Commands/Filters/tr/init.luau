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

local CLASSES = {
	lower = "abcdefghijklmnopqrstuvwxyz",
	upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
	digit = "0123456789",
	space = " \t\n\r\v\f",
	blank = " \t",
	alpha = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
	alnum = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",
	xdigit = "0123456789ABCDEFabcdef",
	punct = "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~",
	cntrl = "\1\2\3\4\5\6\7\8\9\10\11\12\13\14\15\16\17\18\19\20\21\22\23\24\25\26\27\28\29\30\31\127",
	graph = "!\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~",
	print = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~",
}

local ESCAPES = {
	a = "\a", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t", v = "\v",
	["\\"] = "\\", ["0"] = "\0",
}

local function parseSet(spec: string): { string }
	local chars = {}
	local i = 1
	local len = #spec

	while i <= len do
		local c = string.sub(spec, i, i)

		if c == "[" and string.sub(spec, i + 1, i + 1) == ":" then
			local close = string.find(spec, ":]", i + 2, true)
			if close then
				local name = string.sub(spec, i + 2, close - 1)
				local class = CLASSES[name]
				if class then
					for j = 1, #class do table.insert(chars, string.sub(class, j, j)) end
				end
				i = close + 2
				continue
			end
		end

		if c == "\\" and i < len then
			local n = string.sub(spec, i + 1, i + 1)
			if ESCAPES[n] then
				table.insert(chars, ESCAPES[n])
				i += 2
				continue
			elseif string.match(n, "%d") then
				local oct = string.match(string.sub(spec, i + 1), "^[0-7][0-7]?[0-7]?")
				if oct then
					table.insert(chars, string.char(tonumber(oct, 8) % 256))
					i += 1 + #oct
					continue
				end
			else
				table.insert(chars, n)
				i += 2
				continue
			end
		end

		if i + 2 <= len and string.sub(spec, i + 1, i + 1) == "-" then
			local first = string.byte(c)
			local last = string.byte(string.sub(spec, i + 2, i + 2))
			if first and last then
				local step = if first <= last then 1 else -1
				for code = first, last, step do
					table.insert(chars, string.char(code % 256))
				end
				i += 3
				continue
			end
		end

		table.insert(chars, c)
		i += 1
	end

	return chars
end

local function setOf(chars: { string }): { [string]: boolean }
	local set = {}
	for _, c in chars do set[c] = true end
	return set
end

return {
	Name = "tr",
	Permission = "Any",
	Description = "Translate, squeeze, or delete characters from stdin",
	Args = {},
	Run = function(context)
		local options, operands, err = Getopt.parse(context.Args, "cdstC", {
			complement = "c",
			delete = "d",
			squeeze_repeats = "s",
			truncate_set1 = "t",
		})

		if err then
			context:Error(`tr: {err}`, 2)
			return ""
		end

		if #operands < 1 then
			context:Error("tr: missing operand", 2)
			return ""
		end

		local set1Chars = parseSet(operands[1])
		local set2Chars = if operands[2] then parseSet(operands[2]) else {}

		if options.c or options.C then
			local present = setOf(set1Chars)
			local complement = {}
			for code = 0, 255 do
				local c = string.char(code)
				if not present[c] then table.insert(complement, c) end
			end
			set1Chars = complement
		end

		local set1 = setOf(set1Chars)
		local set2 = setOf(set2Chars)
		local mapping = {}
		if #set2Chars > 0 then
			local last = set2Chars[#set2Chars]
			for index, c in set1Chars do
				mapping[c] = set2Chars[index] or last
			end
		end

		local input = context:GetInput()
		local out = {}
		local lastOutput = nil

		for i = 1, #input do
			local c = string.sub(input, i, i)
			local value = c

			if options.d then
				if set1[c] then
					value = nil
				end
			elseif #set2Chars > 0 then
				value = mapping[c] or c
			end

			if value then
				if options.s then
					local squeezeSet = if #set2Chars > 0 then set2 else set1
					if lastOutput == value and squeezeSet[value] then
						value = nil
					end
				end

				if value then
					table.insert(out, value)
					lastOutput = value
				end
			end
		end

		return table.concat(out)
	end,
}
