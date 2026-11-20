--[[
    © 2026 Nodeal Package. All rights reserved.

    This source code is open-source and free for modification and use in your projects.
    However, you may not sell, sublicense, or distribute this framework (or 
    any rebranded version of it) as a standalone product.

    Any public use or redistribution of this module requires this header 
    to remain intact in the source code. For the complete license terms, 
    please visit: https://www.nodeal.dev/license
]]

local Expander = {}

local function findMatchingBrace(text: string, startIdx: number): number?
	local depth = 1
	local i = startIdx + 1
	local len = #text
	while i <= len do
		local char = string.sub(text, i, i)
		if char == "{" then
			depth += 1
		elseif char == "}" then
			depth -= 1
			if depth == 0 then
				return i
			end
		end
		i += 1
	end
	return nil
end

-- The line comes from a client: unbounded, `a{1..999999999}` allocates a billion strings and
-- nested braces multiply each other. A token past the limit is kept as typed.
local MAX_EXPANSIONS = 1000

local function expandToken(token: string): {string}
	local startIdx = string.find(token, "{")
	if not startIdx then
		return {token}
	end

	local endIdx = findMatchingBrace(token, startIdx)
	if not endIdx then
		return {token}
	end

	local prefix = string.sub(token, 1, startIdx - 1)
	local suffix = string.sub(token, endIdx + 1)
	local inner = string.sub(token, startIdx + 1, endIdx - 1)

	local expandedParts = {}

	local numStart, numEnd = string.match(inner, "^(%-?%d+)%.%.(%-?%d+)$")
	if numStart and numEnd then
		local startVal = tonumber(numStart)
		local endVal = tonumber(numEnd)
		if startVal and endVal then
			if math.abs(endVal - startVal) + 1 > MAX_EXPANSIONS then
				return {token}
			end

			local step = startVal <= endVal and 1 or -1
			for v = startVal, endVal, step do
				table.insert(expandedParts, tostring(v))
			end
		end
	else
		local charStart, charEnd = string.match(inner, "^(%a)%.%.(%a)$")
		if charStart and charEnd then
			local startByte = string.byte(charStart)
			local endByte = string.byte(charEnd)
			local step = startByte <= endByte and 1 or -1
			for b = startByte, endByte, step do
				table.insert(expandedParts, string.char(b))
			end
		else
			local parts = {}
			local currentPart = ""
			local depth = 0
			local i = 1
			local innerLen = #inner
			while i <= innerLen do
				local char = string.sub(inner, i, i)
				if char == "{" then
					depth += 1
					currentPart ..= char
				elseif char == "}" then
					depth -= 1
					currentPart ..= char
				elseif char == "," and depth == 0 then
					table.insert(parts, currentPart)
					currentPart = ""
				else
					currentPart ..= char
				end
				i += 1
			end
			table.insert(parts, currentPart)
			expandedParts = parts
		end
	end

	local results = {}
	for _, part in expandedParts do
		local expandedTokenStr = prefix .. part .. suffix
		local subResults = expandToken(expandedTokenStr)

		for _, subToken in subResults do
			-- checked while accumulating, which also bounds nested braces multiplying
			if #results >= MAX_EXPANSIONS then
				return {token}
			end

			table.insert(results, subToken)
		end
	end

	return results
end

--[=[
	Performs brace expansion on a list of tokens.
	Example: ["echo", "hey{1..3}"] -> ["echo", "hey1", "hey2", "hey3"]
]=]
function Expander.expand(tokens: {string}): {string}
	local expandedList = {}
	for _, token in tokens do
		local results = expandToken(token)
		for _, res in results do
			table.insert(expandedList, res)
		end

		-- the whole line too: many tokens just under the limit add up
		if #expandedList > MAX_EXPANSIONS then
			error(`brace expansion too large (more than {MAX_EXPANSIONS} words)`, 0)
		end
	end
	return expandedList
end

return Expander
