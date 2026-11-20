--[[
    © 2026 Nodeal Package. All rights reserved.

    This source code is open-source and free for modification and use in your projects.
    However, you may not sell, sublicense, or distribute this framework (or 
    any rebranded version of it) as a standalone product.

    Any public use or redistribution of this module requires this header 
    to remain intact in the source code. For the complete license terms, 
    please visit: https://www.nodeal.dev/license
]]

local Lexer = {}

--[=[
	Tokenizes a raw command line string into a list of strings representing words and operators.
	Follows Linux CLI behavior: whitespace separates tokens, backslash escapes characters,
	and operators (| , > , ; , && , ||) act as token boundaries.
]=]
function Lexer.tokenize(input: string): {string}
	local tokens = {}
	local currentToken = ""
	local i = 1
	local len = #input

	local function pushCurrent()
		if currentToken ~= "" then
			table.insert(tokens, currentToken)
			currentToken = ""
		end
	end

	while i <= len do
		local char = string.sub(input, i, i)

		if char == "\\" then
			if i < len then
				i += 1
				currentToken ..= string.sub(input, i, i)
			else
				currentToken ..= "\\"
			end
		elseif char == " " or char == "\t" then
			pushCurrent()
		elseif char == "|" then
			pushCurrent()
			local nextChar = string.sub(input, i + 1, i + 1)
			if nextChar == "|" then
				table.insert(tokens, "||")
				i += 1
			else
				table.insert(tokens, "|")
			end
		elseif char == "&" then
			local nextChar = string.sub(input, i + 1, i + 1)
			if nextChar == "&" then
				pushCurrent()
				table.insert(tokens, "&&")
				i += 1
			else
				currentToken ..= char
			end
		elseif char == ">" then
			pushCurrent()
			table.insert(tokens, ">")
		elseif char == ";" then
			pushCurrent()
			table.insert(tokens, ";")
		else
			currentToken ..= char
		end

		i += 1
	end

	pushCurrent()

	return tokens
end

return Lexer
