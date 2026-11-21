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
	Implements the `sed` command: Stream editor for filtering and transforming
	text.
]=]

local Getopt = require(script.Parent.Parent.Parent.Parent.Classes.Getopt)
local Regex = require(script.Parent.Parent.Parent.Parent.Classes.Regex)
local Text = require(script.Parent.Parent.Parent.Parent.Classes.Text)

--[=[
	Reads text up to a delimiter, honouring backslash escapes.

	@param script The script text to parse.
	@param index The position to start at.
	@param delimiter The delimiter to use.

	@return The exit status, standard output and standard error.
]=]
local function readDelimited(script: string, index: number, delimiter: string): (string, number)
	local out = {}
	local i = index

	while i <= #script do
		local c = string.sub(script, i, i)
		if c == "\\" then
			local n = string.sub(script, i + 1, i + 1)
			if n == delimiter then
				table.insert(out, delimiter)
			else
				table.insert(out, c)
				table.insert(out, n)
			end
			i += 2
		elseif c == delimiter then
			return table.concat(out), i + 1
		else
			table.insert(out, c)
			i += 1
		end
	end

	return table.concat(out), i
end

--[=[
	Skips whitespace in a sed script.

	@param script The script text to parse.
	@param index The position to start at.

	@return The resulting number.
]=]
local function skipSpaces(script: string, index: number): number
	while index <= #script and string.match(string.sub(script, index, index), "%s") do
		index += 1
	end
	return index
end

--[=[
	Parses one sed address.

	@param script The script text to parse.
	@param index The position to start at.

	@return The exit status, standard output and standard error.
]=]
local function parseAddress(script: string, index: number): (any, number)
	index = skipSpaces(script, index)
	local c = string.sub(script, index, index)

	if c == "$" then
		return { Type = "last" }, index + 1
	elseif string.match(c, "%d") then
		local number = tonumber(string.match(string.sub(script, index), "^%d+"))
		local nextIndex = index + #tostring(number)
		if string.sub(script, nextIndex, nextIndex) == "~" then
			local step = tonumber(string.match(string.sub(script, nextIndex + 1), "^%d+"))
			if step then
				return { Type = "step", Number = number, Step = step },
					nextIndex + 1 + #tostring(step)
			end
		end
		return { Type = "number", Number = number }, nextIndex
	elseif c == "/" then
		local pattern, nextIndex = readDelimited(script, index + 1, "/")
		return { Type = "regex", Pattern = pattern }, nextIndex
	elseif c == "\\" then
		local delimiter = string.sub(script, index + 1, index + 1)
		if delimiter == "" then
			return nil, index
		end
		local pattern, nextIndex = readDelimited(script, index + 2, delimiter)
		return { Type = "regex", Pattern = pattern }, nextIndex
	end

	return nil, index
end

--[=[
	Parses a sed script into commands.

	@param script The script text to parse.

	@return The exit status, standard output and standard error.
]=]
local function parseScript(script: string): (any?, string?)
	local commands = {}
	local index = 1

	while index <= #script do
		index = skipSpaces(script, index)
		if index > #script then
			break
		end
		if string.sub(script, index, index) == "\n" or string.sub(script, index, index) == ";" then
			index += 1
			continue
		end

		local first, afterFirst = parseAddress(script, index)
		local second = nil
		index = afterFirst

		if first then
			index = skipSpaces(script, index)
			if string.sub(script, index, index) == "," then
				index += 1
				second, index = parseAddress(script, index)
			end
		end

		index = skipSpaces(script, index)
		local negate = false
		if string.sub(script, index, index) == "!" then
			negate = true
			index += 1
			index = skipSpaces(script, index)
		end

		local command = string.sub(script, index, index)
		if command == "" then
			break
		end
		index += 1

		local item = {
			First = first,
			Second = second,
			Negate = negate,
			Command = command,
			Active = false,
		}

		if command == "s" or command == "y" then
			local delimiter = string.sub(script, index, index)
			if delimiter == "" then
				return nil, "missing delimiter"
			end
			index += 1
			local firstPart, nextIndex = readDelimited(script, index, delimiter)
			index = nextIndex
			local secondPart, afterSecond = readDelimited(script, index, delimiter)
			index = afterSecond
			item.Pattern = firstPart
			item.Replacement = secondPart

			local flags = {}
			while index <= #script do
				local c = string.sub(script, index, index)
				if c == ";" or c == "\n" then
					break
				end
				if string.match(c, "%s") then
					index += 1
				else
					table.insert(flags, c)
					index += 1
				end
			end
			item.Flags = table.concat(flags)
		elseif command == "a" or command == "i" or command == "c" then
			local start = index
			while index <= #script do
				local c = string.sub(script, index, index)
				if c == ";" or c == "\n" then
					break
				end
				index += 1
			end
			local text = string.sub(script, start, index - 1)
			text = string.gsub(text, "^%s*\\?", "")
			item.Text = text
		elseif command == "q" or command == "Q" then
			local number = string.match(string.sub(script, index), "^%s*(%d+)")
			if number then
				item.Code = tonumber(number)
				index += #number
			end
		elseif command == "b" or command == "t" or command == ":" then
			local label = string.match(string.sub(script, index), "^%s*([%w_]*)")
			item.Label = label or ""
			index += #(label or "")
		elseif command == "{" or command == "}" then
			-- blocks are accepted but not interpreted specially
		elseif command == "r" or command == "w" then
			return nil, `'{command}' needs a filesystem`
		end

		table.insert(commands, item)
	end

	return commands, nil
end

--[=[
	Compiles a sed pattern as a BRE or ERE.

	@param pattern The pattern to match.
	@param ignoreCase Whether matching ignores case.
	@param basic Whether to use basic regular expressions.

	@return The compiled regular expression.
]=]
local function regexFor(pattern: string, ignoreCase: boolean, basic: boolean): any
	local translated = if basic then Regex.breToEre(pattern) else pattern
	return Regex.compile(translated, ignoreCase)
end

--[=[
	Expands `&` and `\1` in a replacement string.

	@param replacement The replacement text.
	@param matched The already matched segments.
	@param captures The capture table.

	@return The resulting text.
]=]
local function expandReplacement(replacement: string, matched: string, captures): string
	local out = {}
	local i = 1

	while i <= #replacement do
		local c = string.sub(replacement, i, i)
		if c == "\\" then
			local n = string.sub(replacement, i + 1, i + 1)
			if n == "&" then
				table.insert(out, "&")
				i += 2
			elseif n == "\\" then
				table.insert(out, "\\")
				i += 2
			elseif n == "n" then
				table.insert(out, "\n")
				i += 2
			elseif n == "t" then
				table.insert(out, "\t")
				i += 2
			elseif string.match(n, "%d") then
				local index = tonumber(n)
				local capture = captures and captures[index]
				if capture == nil then
					table.insert(out, c)
					table.insert(out, n)
				else
					table.insert(out, tostring(capture))
				end
				i += 2
			else
				table.insert(out, n)
				i += 2
			end
		elseif c == "&" then
			table.insert(out, matched)
			i += 1
		else
			table.insert(out, c)
			i += 1
		end
	end

	return table.concat(out)
end

--[=[
	Replaces matches on one line.

	@param line The line to process.
	@param matcher The matcher to apply.
	@param replacement The replacement text.
	@param global Whether to replace every match.
	@param nth The field number to extract.

	@return The exit status, standard output and standard error.
]=]
local function replaceMatches(
	line: string,
	matcher,
	replacement: string,
	global: boolean,
	nth: number?
): (string, number)
	local out = {}
	local position = 1
	local count = 0
	local replaced = 0

	while position <= #line do
		local s, e, captures = matcher:Find(line, position)
		if not s then
			break
		end
		count += 1

		local include = if nth then count == nth else true
		if include and (global or replaced == 0) then
			table.insert(out, string.sub(line, position, s - 1))
			table.insert(out, expandReplacement(replacement, string.sub(line, s, e), captures))
			position = e + 1
			replaced += 1
			if not global and not nth then
				break
			end
		else
			table.insert(out, string.sub(line, position, s))
			position = s + 1
		end
	end

	if replaced == 0 then
		return line, 0
	end

	table.insert(out, string.sub(line, position))
	return table.concat(out), replaced
end

return {
	Name = "sed",
	Permission = "Any",
	Description = "Stream editor for filtering and transforming text",
	Args = {},
	--[=[
		Stream editor for filtering and transforming text.

		@param context The command context.
		@return A status message when the command succeeds.
	]=]
	Run = function(context)
		local options, operands, errorValue = Getopt.parse(context.Args, "ne:f:irEsuz", {
			quiet = "n",
			silent = "n",
			expression = "e",
			file = "f",
			in_place = "i",
			regexp_extended = "E",
			separate = "s",
			unbuffered = "u",
			zero_terminated = "z",
		})

		if errorValue then
			context:Error(`sed: {errorValue}`, 2)
			return ""
		end

		if options.i then
			context:Error("sed: -i: there is no filesystem", 2)
			return ""
		end

		local script = options.e
		if not script then
			script = table.remove(operands, 1)
		end

		if not script then
			context:Error("sed: no script specified", 2)
			return ""
		end

		if #operands > 0 then
			context:Error(`sed: {operands[1]}: No such file or directory`, 2)
			return ""
		end

		local commands, parseError = parseScript(script)
		if not commands then
			context:Error(`sed: {parseError}`, 2)
			return ""
		end

		local quiet = options.n == true
		local extended = options.E == true
		local lines = Text.lines(context:GetInput())
		local out = {}
		local stop = false
		local exitCode = 0

		for lineIndex, original in lines do
			if stop then
				break
			end
			local line = original
			local deleted = false
			local appendText = nil

			--[=[
				Appends one output line.

				@param value The value to convert.
			]=]
			local function emit(value: string)
				table.insert(out, value)
			end

			for _, item in commands do
				local applies = true
				if item.First then
					local firstMatch = false
					if item.First.Type == "last" then
						firstMatch = lineIndex == #lines
					elseif item.First.Type == "number" then
						firstMatch = lineIndex == item.First.Number
					elseif item.First.Type == "step" then
						firstMatch = item.First.Step > 0
							and lineIndex % item.First.Step
								== item.First.Number % item.First.Step
					elseif item.First.Type == "regex" then
						firstMatch = regexFor(item.First.Pattern, false, not extended):Test(line)
					end

					if item.Second then
						if not item.Active and firstMatch then
							item.Active = true
						end
						applies = item.Active
						local secondMatch = false
						if item.Second.Type == "last" then
							secondMatch = lineIndex == #lines
						elseif item.Second.Type == "number" then
							secondMatch = lineIndex == item.Second.Number
						elseif item.Second.Type == "regex" then
							secondMatch =
								regexFor(item.Second.Pattern, false, not extended):Test(line)
						end
						if applies and secondMatch then
							item.Active = false
						end
					else
						applies = firstMatch
					end
				end

				if item.Negate then
					applies = not applies
				end
				if not applies then
					continue
				end

				if item.Command == "d" then
					deleted = true
					break
				elseif item.Command == "p" then
					emit(line)
				elseif item.Command == "=" then
					emit(tostring(lineIndex))
				elseif item.Command == "q" or item.Command == "Q" then
					if not quiet and not deleted then
						emit(line)
					end
					deleted = true
					stop = true
					if item.Code then
						exitCode = item.Code
					end
					break
				elseif item.Command == "s" then
					local ignoreCase = string.find(item.Flags or "", "[iI]", 1) ~= nil
					local global = string.find(item.Flags or "", "g", 1, true) ~= nil
					local nth = tonumber(string.match(item.Flags or "", "(%d+)"))
					local matcher = regexFor(item.Pattern, ignoreCase, not extended)
					local replaced, count =
						replaceMatches(line, matcher, item.Replacement, global, nth)
					if count > 0 then
						line = replaced
						if string.find(item.Flags or "", "p", 1, true) then
							emit(line)
						end
					end
				elseif item.Command == "y" then
					local source = item.Pattern
					local target = item.Replacement
					local map = {}
					for i = 1, math.min(#source, #target) do
						map[string.sub(source, i, i)] = string.sub(target, i, i)
					end
					local chars = {}
					for i = 1, #line do
						local c = string.sub(line, i, i)
						table.insert(chars, map[c] or c)
					end
					line = table.concat(chars)
				elseif item.Command == "a" then
					appendText = item.Text
				elseif item.Command == "i" then
					if item.Text and item.Text ~= "" then
						emit(item.Text)
					end
				elseif item.Command == "c" then
					if item.Text and item.Text ~= "" then
						emit(item.Text)
					end
					deleted = true
					break
				end
			end

			if not quiet and not deleted then
				emit(line)
			end
			if appendText and appendText ~= "" then
				emit(appendText)
			end
		end

		if exitCode ~= 0 then
			context:SetCode(exitCode)
		end

		return table.concat(out, "\n")
	end,
}
