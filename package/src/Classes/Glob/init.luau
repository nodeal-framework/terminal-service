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
	Shell pattern matching (`*`, `?`, `[...]`, POSIX character classes).

	This is the matcher used by `case`, `${var#pattern}` and `[[ x == pattern ]]`.
	It compiles a glob to a Lua pattern, anchored at both ends by Match().
]=]

local Glob = {}

local CLASSES: { [string]: string } = {
	["alpha"] = "A-Za-z",
	["alnum"] = "A-Za-z0-9",
	["digit"] = "0-9",
	["lower"] = "a-z",
	["upper"] = "A-Z",
	["space"] = " \t\r\n\v\f",
	["blank"] = " \t",
	["punct"] = "%!%\"%#%$%%%&%'%(%)%*%+%,%-%./:;%<=%>%?@%[%\\%]%^_`%{%|%}~",
	["xdigit"] = "A-Fa-f0-9",
	["cntrl"] = "%z\1-\31\127",
	["graph"] = "!-~",
	["print"] = " -~",
}

--[=[
	Escapes a character so Lua patterns treat it literally.

	@param c The character to test.
	@return The resulting text.
]=]
local function escapeLua(c: string): string
	if string.find(c, "[%^%$%(%)%%%.%[%]%*%+%-%?]") then
		return "%" .. c
	end
	return c
end

--[=[
	Escapes a character inside a Lua pattern set.

	@param c The character to test.
	@return The resulting text.
]=]
local function escapeSet(c: string): string
	if c == "%" then
		return "%%"
	end
	if c == "]" then
		return "%]"
	end
	return c
end

--[=[
	Compiles a glob to an unanchored Lua pattern.

	@param pattern The pattern to match.
]=]
function Glob.toLua(pattern: string): string
	local out = {}
	local i = 1
	local length = #pattern

	while i <= length do
		local c = string.sub(pattern, i, i)

		if c == "\\" then
			local n = string.sub(pattern, i + 1, i + 1)
			if n ~= "" then
				table.insert(out, escapeLua(n))
				i += 2
			else
				table.insert(out, "%\\")
				i += 1
			end
		elseif c == "*" then
			table.insert(out, ".*")
			i += 1
			while string.sub(pattern, i, i) == "*" do
				i += 1
			end
		elseif c == "?" then
			table.insert(out, ".")
			i += 1
		elseif c == "[" then
			local j = i + 1
			local negate = false
			if string.sub(pattern, j, j) == "!" or string.sub(pattern, j, j) == "^" then
				negate = true
				j += 1
			end

			local set = {}
			if string.sub(pattern, j, j) == "]" then
				table.insert(set, "%]")
				j += 1
			end

			local closed = false
			while j <= length do
				local d = string.sub(pattern, j, j)
				if d == "]" then
					closed = true
					break
				elseif d == "[" and string.sub(pattern, j + 1, j + 1) == ":" then
					local close = string.find(pattern, ":]", j + 2, true)
					if close then
						local name = string.sub(pattern, j + 2, close - 1)
						local class = CLASSES[name]
						if class then
							table.insert(set, class)
						end
						j = close + 2
					else
						table.insert(set, "[")
						j += 1
					end
				elseif d == "\\" then
					local n = string.sub(pattern, j + 1, j + 1)
					if n ~= "" then
						table.insert(set, escapeSet(n))
						j += 2
					else
						table.insert(set, "%%")
						j += 1
					end
				else
					table.insert(set, escapeSet(d))
					j += 1
				end
			end

			if closed then
				table.insert(out, "[" .. (if negate then "^" else "") .. table.concat(set) .. "]")
				i = j + 1
			else
				table.insert(out, "%[")
				i += 1
			end
		else
			table.insert(out, escapeLua(c))
			i += 1
		end
	end

	return table.concat(out)
end

--[=[
	True when the whole text matches the glob.

	@param text The text to inspect.
	@param pattern The pattern to match.
	@param ignoreCase Whether matching ignores case.
]=]
function Glob.match(text: string, pattern: string, ignoreCase: boolean?): boolean
	if ignoreCase then
		text = string.lower(text)
		pattern = string.lower(pattern)
	end

	local ok, found = pcall(string.find, text, "^" .. Glob.toLua(pattern) .. "$")
	return ok and found ~= nil
end

--[=[
	Finds the first glob match inside text. Returns start, end (Lua indices).

	@param text The text to inspect.
	@param pattern The pattern to match.
	@param init The position to start searching from.
	@param ignoreCase Whether matching ignores case.
]=]
function Glob.find(
	text: string,
	pattern: string,
	init: number?,
	ignoreCase: boolean?
): (number?, number?)
	if ignoreCase then
		text = string.lower(text)
		pattern = string.lower(pattern)
	end

	local ok, s, e = pcall(string.find, text, Glob.toLua(pattern), init or 1)
	if not ok then
		return nil, nil
	end
	return s, e
end

return Glob
