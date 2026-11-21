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
	Expansion engine, run after parsing and per command (as Bash does).

	Order: brace expansion, tilde expansion, parameter/command/arithmetic expansion,
	word splitting, quote removal. Pathname expansion is intentionally absent: this
	terminal has no filesystem. The shell object supplies variables, positional
	parameters and command substitution, so this module stays independent of it.
]=]

local Glob = require(script.Parent.Parent.Parent.Classes.Glob)

local Expander = {}

local MAX_BRACE = 1000
local MAX_FIELDS = 4096

type Segment = {
	Text: string?,
	Quoted: boolean?,
	Boundary: boolean?,
}

local function concatParts(parts): string
	local out = {}
	for _, part in parts do
		table.insert(out, part.Text)
	end
	return table.concat(out)
end

local function findMatching(text: string, startIdx: number, openChar: string, closeChar: string): number?
	local depth = 0
	local i = startIdx
	local len = #text
	local quote = 0

	while i <= len do
		local c = string.sub(text, i, i)

		if quote == 1 then
			if c == "'" then quote = 0 end
		elseif quote == 2 then
			if c == "\\" then
				i += 1
			elseif c == "\"" then
				quote = 0
			end
		else
			if c == "\\" then
				i += 1
			elseif c == "'" then
				quote = 1
			elseif c == "\"" then
				quote = 2
			elseif c == openChar then
				depth += 1
			elseif c == closeChar then
				depth -= 1
				if depth == 0 then
					return i
				end
			end
		end

		i += 1
	end

	return nil
end

--// Brace expansion //--

local function splitTopLevel(text: string, separator: string): { string }
	local parts = {}
	local current = {}
	local depth = 0
	local quote = 0
	local i = 1
	local len = #text

	while i <= len do
		local c = string.sub(text, i, i)

		if quote == 1 then
			table.insert(current, c)
			if c == "'" then quote = 0 end
		elseif quote == 2 then
			table.insert(current, c)
			if c == "\\" and i < len then
				i += 1
				table.insert(current, string.sub(text, i, i))
			elseif c == "\"" then
				quote = 0
			end
		else
			if c == "\\" and i < len then
				table.insert(current, c)
				i += 1
				table.insert(current, string.sub(text, i, i))
			elseif c == "'" then
				quote = 1
				table.insert(current, c)
			elseif c == "\"" then
				quote = 2
				table.insert(current, c)
			elseif c == "{" then
				depth += 1
				table.insert(current, c)
			elseif c == "}" then
				depth -= 1
				table.insert(current, c)
			elseif c == separator and depth == 0 then
				table.insert(parts, table.concat(current))
				current = {}
			else
				table.insert(current, c)
			end
		end

		i += 1
	end

	table.insert(parts, table.concat(current))
	return parts
end

local function findBrace(text: string, startIdx: number): number?
	local depth = 1
	local i = startIdx + 1
	local len = #text

	while i <= len do
		local c = string.sub(text, i, i)
		if c == "{" then
			depth += 1
		elseif c == "}" then
			depth -= 1
			if depth == 0 then return i end
		end
		i += 1
	end

	return nil
end

local function expandBraceText(text: string): { string }
	local braceStart = nil
	local i = 1

	while i <= #text do
		local c = string.sub(text, i, i)
		if c == "{" and (i == 1 or string.sub(text, i - 1, i - 1) ~= "$") then
			braceStart = i
			break
		end
		i += 1
	end

	if not braceStart then
		return { text }
	end

	local braceEnd = findBrace(text, braceStart)
	if not braceEnd then
		return { text }
	end

	local prefix = string.sub(text, 1, braceStart - 1)
	local suffix = string.sub(text, braceEnd + 1)
	local inner = string.sub(text, braceStart + 1, braceEnd - 1)
	local values = {}

	local startNum, endNum, stepNum = string.match(inner, "^%s*(-?%d+)%.%.(-?%d+)%.%.(-?%d+)%s*$")
	local startNum2, endNum2 = string.match(inner, "^%s*(-?%d+)%.%.(-?%d+)%s*$")
	local startChar2, endChar2, charStep = string.match(inner, "^(%a)%.%.(%a)%.%.(-?%d+)$")
	local startChar3, endChar3 = string.match(inner, "^(%a)%.%.(%a)$")

	if startNum then
		local a, b, step = tonumber(startNum), tonumber(endNum), tonumber(stepNum)
		if step == 0 then return { text } end
		step = if a <= b then math.abs(step) else -math.abs(step)
		if (b - a) * step < 0 then return { text } end
		local width = math.max(#string.gsub(startNum, "^-", ""), #string.gsub(endNum, "^-", ""))
		local pad = string.match(startNum, "^-?0%d") ~= nil or string.match(endNum, "^-?0%d") ~= nil
		for v = a, b, step do
			if #values >= MAX_BRACE then return { text } end
			local s = tostring(v)
			if pad then
				local sign = if v < 0 then "-" else ""
				s = sign .. string.rep("0", math.max(0, width - #string.gsub(s, "^-", ""))) .. string.gsub(s, "^-", "")
			end
			table.insert(values, s)
		end
	elseif startNum2 then
		local a, b = tonumber(startNum2), tonumber(endNum2)
		local step = if a <= b then 1 else -1
		local width = math.max(#string.gsub(startNum2, "^-", ""), #string.gsub(endNum2, "^-", ""))
		local pad = string.match(startNum2, "^-?0%d") ~= nil or string.match(endNum2, "^-?0%d") ~= nil
		for v = a, b, step do
			if #values >= MAX_BRACE then return { text } end
			local s = tostring(v)
			if pad then
				local sign = if v < 0 then "-" else ""
				s = sign .. string.rep("0", math.max(0, width - #string.gsub(s, "^-", ""))) .. string.gsub(s, "^-", "")
			end
			table.insert(values, s)
		end
	elseif startChar2 then
		local a, b, step = string.byte(startChar2), string.byte(endChar2), tonumber(charStep)
		if step == 0 then return { text } end
		step = if a <= b then math.abs(step) else -math.abs(step)
		if (b - a) * step < 0 then return { text } end
		for v = a, b, step do
			if #values >= MAX_BRACE then return { text } end
			table.insert(values, string.char(v))
		end
	elseif startChar3 then
		local a, b = string.byte(startChar3), string.byte(endChar3)
		local step = if a <= b then 1 else -1
		for v = a, b, step do
			if #values >= MAX_BRACE then return { text } end
			table.insert(values, string.char(v))
		end
	else
		local pieces = splitTopLevel(inner, ",")
		if #pieces <= 1 then
			return { text }
		end
		values = pieces
	end

	local results = {}
	for _, value in values do
		local sub = expandBraceText(prefix .. value .. suffix)
		for _, item in sub do
			if #results >= MAX_BRACE then
				return { text }
			end
			table.insert(results, item)
		end
	end

	return results
end

local function braceExpandParts(parts): { { any } }
	local variants = { {} }

	for _, part in parts do
		local options = if part.Quote == 0 then expandBraceText(part.Text) else { part.Text }
		local nextVariants = {}

		for _, variant in variants do
			for _, option in options do
				local copy = table.clone(variant)
				table.insert(copy, { Text = option, Quote = part.Quote })
				table.insert(nextVariants, copy)
				if #nextVariants > MAX_BRACE then
					error("brace expansion too large", 0)
				end
			end
		end

		variants = nextVariants
	end

	return variants
end

--// Expansion helpers //--

local function appendLiteral(segments: { Segment }, text: string, quote: number)
	if text == "" and quote == 0 then
		return
	end

	if quote == 0 then
		table.insert(segments, { Text = text, Quoted = false })
	else
		table.insert(segments, { Text = text, Quoted = true })
	end
end

local function segmentsToString(segments: { Segment }): string
	local out = {}
	for _, segment in segments do
		if not segment.Boundary and segment.Text then
			table.insert(out, segment.Text)
		end
	end
	return table.concat(out)
end

local function firstIfs(shell): string
	local ifs = shell:GetVar("IFS")
	if ifs == nil then ifs = " \t\n" end
	return string.sub(ifs, 1, 1)
end

local function joinPositional(shell, skipEmpty: boolean): string
	local out = {}
	for _, value in shell:GetPositional() do
		if not skipEmpty or value ~= "" then
			table.insert(out, value)
		end
	end
	return table.concat(out, " ")
end

local function arrayValues(shell, name: string): { string }?
	local array = shell.Arrays and shell.Arrays[name]
	if not array then
		return nil
	end

	local values = {}
	for index = 0, (array.n or 0) - 1 do
		table.insert(values, array[index] or "")
	end
	return values
end

local function resolveSubscript(shell, subscript: string): number
	if subscript == "" then return 0 end

	local ok, value = pcall(shell.Arithmetic, shell, subscript)
	if ok and type(value) == "number" then
		return math.floor(value)
	end

	return tonumber(subscript) or 0
end

local function arrayElement(shell, name: string, subscript: string): string?
	local array = shell.Arrays and shell.Arrays[name]
	if not array then
		return nil
	end

	local index = resolveSubscript(shell, subscript)
	local count = array.n or 0
	if index < 0 then
		index = count + index
	end

	return array[index]
end

local function specialValue(shell, name: string): string?
	if name == "?" then return tostring(shell.Status) end
	if name == "$" then return tostring(shell.Pid) end
	if name == "!" then
		if shell.LastBg then
			return tostring(shell.LastBg)
		end
		return ""
	end
	if name == "#" then return tostring(#shell:GetPositional()) end
	if name == "-" then return shell:OptionFlags() end
	if name == "_" then return shell.LastArg or "" end
	if name == "0" then return shell.Name end
	if name == "@" or name == "*" then return joinPositional(shell, false) end

	local digit = tonumber(name)
	if digit and digit >= 1 and digit <= 9 then
		return shell:GetPositional()[digit]
	end

	local value = shell:GetVar(name)
	if value ~= nil then
		return value
	end

	local array = shell.Arrays and shell.Arrays[name]
	if array then
		return array[0]
	end

	return nil
end

local function isUnset(shell, name: string, subscript: string?): boolean
	if subscript then
		return arrayElement(shell, name, subscript) == nil
	end
	return specialValue(shell, name) == nil
end

local function isEmpty(shell, name: string, subscript: string?): boolean
	local value = if subscript then arrayElement(shell, name, subscript) else specialValue(shell, name)
	return value == nil or value == ""
end

-- Resolves the body of `${name<op>word}`.
local function parameterExpansion(shell, content: string, quoted: boolean): string
	if string.sub(content, 1, 1) == "#" and string.sub(content, 2, 2) ~= "" then
		local rest = string.sub(content, 2)
		if string.match(rest, "^[%a_][%w_]*$") or string.match(rest, "^[@*#?%$!%-]$") then
			local value = specialValue(shell, rest)
			return tostring(#(value or ""))
		end

		local arrayName, subscript = string.match(rest, "^([%a_][%w_]*)%[([^%]]*)%]$")
		if arrayName then
			if subscript == "@" or subscript == "*" then
				return tostring(#(arrayValues(shell, arrayName) or {}))
			end
			return tostring(#(arrayElement(shell, arrayName, subscript) or ""))
		end
	end

	local name = nil
	local rest = ""

	local indirect = string.sub(content, 1, 1) == "!"
	if indirect then
		content = string.sub(content, 2)
	end

	local special = string.match(content, "^([@*#?%$!%-])")
	if special then
		name = special
		rest = string.sub(content, 2)
	elseif string.match(content, "^%d+") then
		name = string.match(content, "^%d+")
		rest = string.sub(content, #name + 1)
	else
		name = string.match(content, "^[%a_][%w_]*")
		if not name then
			return ""
		end
		rest = string.sub(content, #name + 1)
	end

	if indirect then
		local target = specialValue(shell, name)
		if not target or target == "" then return "" end
		name = target
	end

	local subscript = nil
	if string.sub(rest, 1, 1) == "[" then
		local close = string.find(rest, "]", 2, true)
		if close then
			subscript = string.sub(rest, 2, close - 1)
			rest = string.sub(rest, close + 1)
		end
	end

	local function current(): string?
		if subscript then
			return arrayElement(shell, name, subscript)
		end
		return specialValue(shell, name)
	end

	-- ${var:-word}, ${var:=word}, ${var:+word}, ${var:?word} and the unset-only forms
	local op, word = string.match(rest, "^(%:?[-=+?])(.*)$")
	if op then
		local useEmpty = string.sub(op, 1, 1) == ":"
		local kind = string.sub(op, #op, #op)
		local unset = if useEmpty then isEmpty(shell, name, subscript) else isUnset(shell, name, subscript)
		local expandedWord = shell:ExpandInline(word)

		if kind == "-" then
			if unset then
				return expandedWord
			end
		elseif kind == "=" then
			if unset then
				shell:SetVar(name, expandedWord)
				return expandedWord
			end
		elseif kind == "+" then
			if not unset then
				return expandedWord
			end
			return ""
		elseif kind == "?" then
			if unset then
				error(`{name}: {if expandedWord ~= "" then expandedWord else "parameter not set"}`, 0)
			end
			return current() or ""
		end

		return current() or ""
	end

	-- ${var#pattern}, ${var##pattern}, ${var%pattern}, ${var%%pattern}
	local trimOp, pattern = nil, ""
	if string.sub(rest, 1, 2) == "##" then
		trimOp, pattern = "##", string.sub(rest, 3)
	elseif string.sub(rest, 1, 1) == "#" then
		trimOp, pattern = "#", string.sub(rest, 2)
	elseif string.sub(rest, 1, 2) == "%%" then
		trimOp, pattern = "%%", string.sub(rest, 3)
	elseif string.sub(rest, 1, 1) == "%" then
		trimOp, pattern = "%", string.sub(rest, 2)
	end

	if trimOp then
		local value = current() or ""
		local longest = #trimOp == 2
		local fromEnd = string.sub(trimOp, 1, 1) == "%"
		pattern = shell:ExpandInline(pattern)

		if pattern == "" then
			return value
		end

		if not fromEnd then
			local range = longest and #value or 0
			if longest then
				for i = #value, 0, -1 do
					if Glob.match(string.sub(value, 1, i), pattern) then
						range = i
						break
					end
				end
			else
				range = 0
				for i = 0, #value do
					if Glob.match(string.sub(value, 1, i), pattern) then
						range = i
						break
					end
				end
			end
			return string.sub(value, range + 1)
		else
			local best = nil
			if longest then
				for i = 0, #value do
					if Glob.match(string.sub(value, i + 1), pattern) then
						best = i
						break
					end
				end
			else
				for i = #value, 0, -1 do
					if Glob.match(string.sub(value, i + 1), pattern) then
						best = i
						break
					end
				end
			end
			return string.sub(value, 1, best or #value)
		end
	end

	-- ${var/pat/repl}, ${var//pat/repl}, ${var/#pat/repl}, ${var/%pat/repl}
	if string.sub(rest, 1, 1) == "/" then
		local body = string.sub(rest, 2)
		local global = false
		local anchorStart = false
		local anchorEnd = false

		if string.sub(body, 1, 1) == "/" then
			global = true
			body = string.sub(body, 2)
		elseif string.sub(body, 1, 1) == "#" then
			anchorStart = true
			body = string.sub(body, 2)
		elseif string.sub(body, 1, 1) == "%" then
			anchorEnd = true
			body = string.sub(body, 2)
		end

		local split = nil
		local escape = false
		for i = 1, #body do
			local c = string.sub(body, i, i)
			if escape then
				escape = false
			elseif c == "\\" then
				escape = true
			elseif c == "/" then
				split = i
				break
			end
		end

		local pat = if split then string.sub(body, 1, split - 1) else body
		local repl = if split then string.sub(body, split + 1) else ""
		pat = shell:ExpandInline(pat)
		repl = shell:ExpandInline(repl)
		local value = current() or ""
		local luaPattern = Glob.toLua(pat)

		if anchorStart then luaPattern = "^" .. luaPattern end
		if anchorEnd then luaPattern = luaPattern .. "$" end

		local replaced = string.gsub(value, luaPattern, function(match)
			return string.gsub(repl, "&", match)
		end, if global then nil else 1)

		return replaced
	end

	-- ${var:offset[:length]}
	local offsetText, lengthText = string.match(rest, "^: *(-?%d+) *:? *(-?%d*)%s*$")
	if offsetText then
		local value = current() or ""
		local offset = tonumber(offsetText) or 0
		if offset < 0 then offset = math.max(0, #value + offset) end
		local length = tonumber(lengthText)
		if lengthText == "" or lengthText == nil then
			return string.sub(value, offset + 1)
		end
		if length < 0 then
			return string.sub(value, offset + 1, #value + length + offset)
		end
		return string.sub(value, offset + 1, offset + length)
	end

	-- ${var^}, ${var^^}, ${var,}, ${var,,}
	local caseOp, casePattern = nil, ""
	if string.sub(rest, 1, 2) == "^^" then
		caseOp, casePattern = "^^", string.sub(rest, 3)
	elseif string.sub(rest, 1, 1) == "^" then
		caseOp, casePattern = "^", string.sub(rest, 2)
	elseif string.sub(rest, 1, 2) == ",," then
		caseOp, casePattern = ",,", string.sub(rest, 3)
	elseif string.sub(rest, 1, 1) == "," then
		caseOp, casePattern = ",", string.sub(rest, 2)
	end

	if caseOp then
		local value = current() or ""
		local upper = string.sub(caseOp, 1, 1) == "^"
		local all = #caseOp == 2
		if value == "" then return value end

		if not all then
			local first = string.sub(value, 1, 1)
			first = if upper then string.upper(first) else string.lower(first)
			return first .. string.sub(value, 2)
		end

		if upper then
			return string.upper(value)
		end
		return string.lower(value)
	end

	local value = current()
	if value == nil and shell.Options and shell.Options.nounset then
		error(`${name}: unbound variable`, 0)
	end
	return value or ""
end

local function expandText(text: string, quote: number, shell, segments: { Segment })
	if text == "" then
		if quote ~= 0 then
			table.insert(segments, { Text = "", Quoted = true })
		end
		return
	end

	local i = 1
	local len = #text
	local literal = {}

	local function flush()
		if #literal > 0 then
			appendLiteral(segments, table.concat(literal), quote)
			literal = {}
		end
	end

	while i <= len do
		local c = string.sub(text, i, i)

		if c == "$" and quote ~= 1 then
			local n = string.sub(text, i + 1, i + 1)

			if n == "(" then
				local close = findMatching(text, i + 1, "(", ")")
				if not close then
					error("unexpected EOF while looking for matching `)'", 0)
				end

				local inner = string.sub(text, i + 2, close - 1)

				if string.sub(inner, 1, 1) == "(" and string.sub(inner, -1, -1) == ")" then
					flush()
					local value = shell:Arithmetic(string.sub(inner, 2, -2))
					appendLiteral(segments, tostring(value), quote)
				else
					flush()
					local output = shell:CommandSubstitute(inner)
					appendLiteral(segments, output, quote)
				end

				i = close + 1
			elseif n == "{" then
				local close = findMatching(text, i + 1, "{", "}")
				if not close then
					error("unexpected EOF while looking for matching `}'", 0)
				end

				flush()
				local content = string.sub(text, i + 2, close - 1)

				local arrayName, arraySubscript = string.match(content, "^([%a_][%w_]*)%[([^%]]*)%]$")
				if arrayName and (arraySubscript == "@" or arraySubscript == "*") then
					local values = arrayValues(shell, arrayName) or {}
					if arraySubscript == "*" and quote == 2 then
						appendLiteral(segments, table.concat(values, " "), 2)
					else
						for index, value in values do
							appendLiteral(segments, value, quote)
							if index < #values then
								table.insert(segments, { Boundary = true })
							end
						end
					end
				elseif content == "@" and quote == 2 then
					local positional = shell:GetPositional()
					for index, value in positional do
						appendLiteral(segments, value, 2)
						if index < #positional then
							table.insert(segments, { Boundary = true })
						end
					end
				elseif content == "*" and quote == 2 then
					appendLiteral(segments, joinPositional(shell, false), 2)
				elseif content == "@" then
					appendLiteral(segments, joinPositional(shell, false), quote)
				elseif content == "*" then
					appendLiteral(segments, joinPositional(shell, false), quote)
				else
					appendLiteral(segments, parameterExpansion(shell, content, quote == 2), quote)
				end

				i = close + 1
			elseif n == "'" then
				-- handled by the lexer, but keep a safe fallback
				flush()
				i += 2
			else
				local name = nil
				local special = string.match(string.sub(text, i + 1), "^([@*#?%$!%-])")
				if special then
					name = special
				else
					name = string.match(string.sub(text, i + 1), "^[%a_][%w_]*")
					if not name then
						name = string.match(string.sub(text, i + 1), "^%d")
					end
				end

				if name then
					flush()

					if name == "@" and quote == 2 then
						local positional = shell:GetPositional()
						for index, value in positional do
							appendLiteral(segments, value, 2)
							if index < #positional then
								table.insert(segments, { Boundary = true })
							end
						end
					elseif name == "*" and quote == 2 then
						appendLiteral(segments, joinPositional(shell, false), 2)
					else
						local value = specialValue(shell, name)
						if value == nil and shell.Options and shell.Options.nounset then
							error(`${name}: unbound variable`, 0)
						end
						appendLiteral(segments, value or "", quote)
					end

					i += 1 + #name
				else
					table.insert(literal, c)
					i += 1
				end
			end
		elseif c == "`" and quote ~= 1 then
			flush()
			local j = i + 1
			local inner = {}
			local closed = false

			while j <= len do
				local d = string.sub(text, j, j)
				if d == "\\" and j < len then
					local nextChar = string.sub(text, j + 1, j + 1)
					if nextChar == "`" or nextChar == "\\" or nextChar == "$" then
						table.insert(inner, nextChar)
						j += 2
					else
						table.insert(inner, d)
						j += 1
					end
				elseif d == "`" then
					closed = true
					break
				else
					table.insert(inner, d)
					j += 1
				end
			end

			if not closed then
				error("unexpected EOF while looking for matching ``'", 0)
			end

			appendLiteral(segments, shell:CommandSubstitute(table.concat(inner)), quote)
			i = j + 1
		elseif c == "~" and quote == 0 and #literal == 0 then
			local nextChar = string.sub(text, i + 1, i + 1)
			if nextChar == "/" or nextChar == "" then
				table.insert(literal, shell:GetVar("HOME") or "/")
				i += 1
			else
				table.insert(literal, c)
				i += 1
			end
		else
			table.insert(literal, c)
			i += 1
		end
	end

	flush()
end

local function splitFields(segments: { Segment }, ifs: string): { string }
	if ifs == "" then
		local value = segmentsToString(segments)
		if value == "" and #segments == 0 then
			return {}
		end
		return { value }
	end

	local fields = {}
	local current = {}
	local hasField = false

	local function push()
		if hasField then
			table.insert(fields, table.concat(current))
			current = {}
			hasField = false
		end
	end

	for _, segment in segments do
		if segment.Boundary then
			push()
		elseif segment.Quoted then
			table.insert(current, segment.Text or "")
			hasField = true
		else
			local text = segment.Text or ""
			local i = 1
			local len = #text

			while i <= len do
				local c = string.sub(text, i, i)
				if string.find(ifs, c, 1, true) then
					push()
				else
					table.insert(current, c)
					hasField = true
				end
				i += 1
			end
		end
	end

	push()

	if #fields > MAX_FIELDS then
		error("too many words after expansion", 0)
	end

	return fields
end

--[=[
	Expands one word token into zero or more fields.
]=]
function Expander.expandWord(token, shell): { string }
	if not token or token.Type ~= "word" then
		return {}
	end

	local ifs = shell:GetVar("IFS")
	if ifs == nil then ifs = " \t\n" end

	local variants = braceExpandParts(token.Parts or {})
	local fields = {}

	for _, parts in variants do
		local segments = {}
		for _, part in parts do
			expandText(part.Text, part.Quote, shell, segments)
		end

		for _, field in splitFields(segments, ifs) do
			table.insert(fields, field)
		end
	end

	return fields
end

--[=[
	Expands a word as a single value: no word splitting (assignment, redirect, case word).
]=]
function Expander.expandWordSingle(token, shell): string
	if not token then return "" end
	if token.Type ~= "word" then return token.Value or "" end

	local variants = braceExpandParts(token.Parts or {})
	local parts = variants[1] or {}
	local segments = {}

	for _, part in parts do
		expandText(part.Text, part.Quote, shell, segments)
	end

	return segmentsToString(segments)
end

--[=[
	Expands a list of word tokens into fields.
]=]
function Expander.expandWords(tokens, shell): { string }
	local words = {}
	for _, token in tokens do
		for _, field in Expander.expandWord(token, shell) do
			table.insert(words, field)
		end
	end
	return words
end

--[=[
	Expands a string as if it were an unquoted word (used by here-strings and eval).
]=]
function Expander.expandString(text: string, shell): { string }
	local segments = {}
	expandText(text, 0, shell, segments)
	local ifs = shell:GetVar("IFS")
	if ifs == nil then ifs = " \t\n" end
	return splitFields(segments, ifs)
end

function Expander.expandStringSingle(text: string, shell): string
	local segments = {}
	expandText(text, 0, shell, segments)
	return segmentsToString(segments)
end

return Expander
