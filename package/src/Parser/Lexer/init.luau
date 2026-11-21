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
	Bash-compatible tokenizer.

	A word is kept as a list of parts. Every part remembers how it was quoted:
	  0 = unquoted, 1 = single quotes, 2 = double quotes.
	Expansion happens later (see Parser/Expander), because in Bash the line is parsed
	before parameter expansion, command substitution and word splitting. Keeping the
	quote mode per part is what makes `echo "{a,b}"` print `{a,b}` while `echo {a,b}`
	prints `a b`, and what stops `x="|"` from becoming a real pipe.

	Operators are only recognised outside quotes. `|`, `||`, `&&`, `;`, `&`, `(`, `)`,
	`<`, `>`, `>>`, `>&`, `&>`, `<<<`, `<<`, `<<-`, `>|`, `|&`, `;;` and the `2>` family
	are returned as operator tokens. Here-document bodies are consumed at the next
	unquoted newline and attached to the `<<` / `<<-` token.
]=]

local Lexer = {}

export type Part = {
	Text: string,
	Quote: number,
}

export type Token = {
	Type: string,
	Value: string?,
	Parts: { Part }?,
	Quoted: boolean?,
}

--[=[
	Checks whether a character is shell whitespace.

	@param c The character to test.
	@return True when the condition holds.
]=]
local function isBlank(c: string): boolean
	return c == " " or c == "\t" or c == "\r" or c == "\n"
end

--[=[
	Checks whether a character can start an operator.

	@param c The character to test.
	@return True when the condition holds.
]=]
local function isOperatorStart(c: string): boolean
	return c == "|" or c == "&" or c == ">" or c == "<" or c == ";" or c == "(" or c == ")"
end

local REDIRECT_OPS = { "<<<", "<<-", "<<", ">>", "<>", ">&", ">", "<" }

--[=[
	Matches the longest operator at a position, including file descriptors.

	@param input The input to process.
	@param i The position to start at.
	@param atWordStart Whether the operator starts a word.
	@return The resulting text, or nil.
]=]
local function matchOperator(input: string, i: number, atWordStart: boolean): string?
	local rest = string.sub(input, i)

	if atWordStart then
		local fd = string.match(rest, "^(%d+)")
		if fd then
			local after = string.sub(rest, #fd + 1)
			for _, op in REDIRECT_OPS do
				if string.sub(after, 1, #op) == op then
					return fd .. op
				end
			end
		end
	end

	local three = string.sub(rest, 1, 3)
	if three == ";;&" or three == "&>>" or three == "<<<" or three == "<<-" then
		return three
	end

	local two = string.sub(rest, 1, 2)
	if
		two == "&&"
		or two == "||"
		or two == "|&"
		or two == ">>"
		or two == ">&"
		or two == "&>"
		or two == "<<"
		or two == "<>"
		or two == ";;"
		or two == ">|"
		or two == ";&"
	then
		return two
	end

	local one = string.sub(rest, 1, 1)
	if
		one == ";"
		or one == "|"
		or one == "&"
		or one == "<"
		or one == ">"
		or one == "("
		or one == ")"
	then
		return one
	end

	return nil
end

--[=[
	Skips a parenthesised group, respecting quotes and nesting.

	@param input The input to process.
	@param startIdx The index to start scanning from.
	@return The resulting number.
]=]
local function consumeParen(input: string, startIdx: number): number
	local depth = 0
	local i = startIdx
	local len = #input
	local quote = 0

	while i <= len do
		local c = string.sub(input, i, i)

		if quote == 1 then
			if c == "'" then
				quote = 0
			end
		elseif quote == 2 then
			if c == "\\" then
				i += 1
			elseif c == '"' then
				quote = 0
			end
		else
			if c == "\\" then
				i += 1
			elseif c == "'" then
				quote = 1
			elseif c == '"' then
				quote = 2
			elseif c == "`" then
				local j = i + 1
				while j <= len do
					local d = string.sub(input, j, j)
					if d == "\\" then
						j += 2
					elseif d == "`" then
						break
					else
						j += 1
					end
				end
				i = j
			elseif c == "(" then
				depth += 1
			elseif c == ")" then
				depth -= 1
				if depth == 0 then
					return i
				end
			end
		end

		i += 1
	end

	error("unexpected EOF while looking for matching `)'", 0)
end

--[=[
	Skips a brace group, respecting quotes and nesting.

	@param input The input to process.
	@param startIdx The index to start scanning from.
	@return The resulting number.
]=]
local function consumeBrace(input: string, startIdx: number): number
	local depth = 0
	local i = startIdx
	local len = #input
	local quote = 0

	while i <= len do
		local c = string.sub(input, i, i)

		if quote == 1 then
			if c == "'" then
				quote = 0
			end
		elseif quote == 2 then
			if c == "\\" then
				i += 1
			elseif c == '"' then
				quote = 0
			end
		else
			if c == "\\" then
				i += 1
			elseif c == "'" then
				quote = 1
			elseif c == '"' then
				quote = 2
			elseif c == "{" then
				depth += 1
			elseif c == "}" then
				depth -= 1
				if depth == 0 then
					return i
				end
			end
		end

		i += 1
	end

	error("unexpected EOF while looking for matching `}'", 0)
end

--[=[
	Skips a backtick command substitution.

	@param input The input to process.
	@param startIdx The index to start scanning from.
	@return The resulting number.
]=]
local function consumeBacktick(input: string, startIdx: number): number
	local i = startIdx + 1
	local len = #input
	while i <= len do
		local c = string.sub(input, i, i)
		if c == "\\" then
			i += 2
		elseif c == "`" then
			return i
		else
			i += 1
		end
	end
	error("unexpected EOF while looking for matching ``'", 0)
end

local ESCAPES: { [string]: string } = {
	["a"] = "\a",
	["b"] = "\b",
	["e"] = "\27",
	["E"] = "\27",
	["f"] = "\f",
	["n"] = "\n",
	["r"] = "\r",
	["t"] = "\t",
	["v"] = "\v",
	["\\"] = "\\",
	["'"] = "'",
	['"'] = '"',
	["?"] = "?",
}

--[=[
	Reads an ANSI-C quoted string.

	@param input The input to process.
	@param startIdx The index to start scanning from.
	@return The exit status, standard output and standard error.
]=]
local function readAnsiC(input: string, startIdx: number): (string, number)
	local out = {}
	local i = startIdx + 1
	local len = #input

	while i <= len do
		local c = string.sub(input, i, i)
		if c == "'" then
			return table.concat(out), i + 1
		elseif c == "\\" then
			local n = string.sub(input, i + 1, i + 1)
			if n == "" then
				break
			end

			if ESCAPES[n] then
				table.insert(out, ESCAPES[n])
				i += 2
			elseif n == "x" then
				local hex = string.match(string.sub(input, i + 2), "^%x%x?")
				if hex then
					table.insert(out, string.char(tonumber(hex, 16) % 256))
					i += 2 + #hex
				else
					table.insert(out, "x")
					i += 2
				end
			elseif n == "u" or n == "U" then
				local count = if n == "u" then 4 else 8
				local hex = string.match(string.sub(input, i + 2), "^%x+")
				if hex then
					hex = string.sub(hex, 1, count)
					local ok, char = pcall(utf8.char, tonumber(hex, 16))
					table.insert(out, if ok then char else "")
					i += 2 + #hex
				else
					table.insert(out, n)
					i += 2
				end
			elseif n == "0" then
				local oct = string.match(string.sub(input, i + 2), "^[0-7][0-7]?[0-7]?")
				if oct then
					table.insert(out, string.char(tonumber(oct, 8) % 256))
					i += 2 + #oct
				else
					table.insert(out, "\0")
					i += 2
				end
			elseif n == "c" then
				local control = string.sub(input, i + 2, i + 2)
				if control ~= "" then
					table.insert(
						out,
						string.char(bit32.band(string.byte(string.upper(control)), 0x1F))
					)
					i += 3
				else
					i += 2
				end
			elseif n == "\n" then
				i += 2
			else
				table.insert(out, "\\")
				table.insert(out, n)
				i += 2
			end
		else
			table.insert(out, c)
			i += 1
		end
	end

	error("unexpected EOF while looking for matching `''", 0)
end

--[=[
	Returns the token list for a line.

	@param input The input to process.
]=]
function Lexer.lex(input: string): { Token }
	local tokens: { Token } = {}
	local parts: { Part } = {}
	local buffer = ""
	local quote = 0
	local hasContent = false
	local wordStarted = false

	local pendingHeredocs = {}
	local pendingHeredocOp = nil

	--[=[
		Flushes the current word buffer as a quoted part.

		@param mode The quoting mode.
	]=]
	local function flush(mode: number)
		if buffer ~= "" then
			table.insert(parts, { Text = buffer, Quote = mode })
			buffer = ""
		end
	end

	--[=[
		Finishes the current word and appends it to the token list.
	]=]
	local function pushWord()
		if not hasContent and #parts == 0 then
			return
		end

		if #parts == 0 then
			table.insert(parts, { Text = "", Quote = 0 })
		end

		local quoted = false
		local text = {}
		for _, part in parts do
			if part.Quote ~= 0 then
				quoted = true
			end
			table.insert(text, part.Text)
		end

		local token = { Type = "word", Parts = parts, Quoted = quoted }
		table.insert(tokens, token)

		if pendingHeredocOp then
			table.insert(pendingHeredocs, {
				Token = pendingHeredocOp,
				Delimiter = table.concat(text),
				Quoted = quoted,
				StripTabs = pendingHeredocOp.Value == "<<-",
			})
			pendingHeredocOp = nil
		end

		parts = {}
		buffer = ""
		hasContent = false
		wordStarted = false
	end

	--[=[
		Appends an operator token.

		@param value The value to convert.
	]=]
	local function pushOp(value: string)
		flush(quote)
		pushWord()
		local token = { Type = "op", Value = value }
		table.insert(tokens, token)
		if value == "<<" or value == "<<-" then
			pendingHeredocOp = token
		end
	end

	--[=[
		Consumes pending here-document bodies after a newline.

		@param startIdx The index to start scanning from.
		@return The resulting number.
	]=]
	local function drainHeredocs(startIdx: number): number
		local index = startIdx
		local length = #input

		for _, entry in pendingHeredocs do
			local chunks = {}

			while index <= length do
				local nl = string.find(input, "\n", index, true)
				local lineEnd = if nl then nl - 1 else length
				local line = string.sub(input, index, lineEnd)
				if string.sub(line, -1) == "\r" then
					line = string.sub(line, 1, -2)
				end

				local compare = line
				if entry.StripTabs then
					compare = string.gsub(compare, "^\t+", "")
				end

				if compare == entry.Delimiter then
					index = if nl then nl + 1 else length + 1
					break
				end

				if entry.StripTabs then
					line = string.gsub(line, "^\t+", "")
				end
				table.insert(chunks, line)
				table.insert(chunks, "\n")
				index = if nl then nl + 1 else length + 1
			end

			entry.Token.HereDoc = {
				Body = table.concat(chunks),
				Expand = not entry.Quoted,
			}
		end

		pendingHeredocs = {}
		return math.min(index, length + 1)
	end

	local i = 1
	local len = #input

	while i <= len do
		local c = string.sub(input, i, i)

		if quote == 0 then
			if c == "\n" then
				flush(0)
				pushWord()
				pendingHeredocOp = nil
				table.insert(tokens, { Type = "op", Value = ";" })
				i += 1
				if #pendingHeredocs > 0 then
					i = drainHeredocs(i)
				end
			elseif isBlank(c) then
				flush(0)
				pushWord()
				i += 1
			elseif c == "#" and not wordStarted then
				local nl = string.find(input, "\n", i, true)
				i = if nl then nl else len + 1
			elseif c == "\\" then
				local n = string.sub(input, i + 1, i + 1)
				if n == "" then
					buffer ..= "\\"
					i += 1
				elseif n == "\n" then
					i += 2
				else
					flush(0)
					table.insert(parts, { Text = n, Quote = 1 })
					wordStarted = true
					hasContent = true
					i += 2
				end
			elseif c == "'" then
				flush(0)
				quote = 1
				wordStarted = true
				hasContent = true
				i += 1
			elseif c == '"' then
				flush(0)
				quote = 2
				wordStarted = true
				hasContent = true
				i += 1
			elseif c == "$" then
				local n = string.sub(input, i + 1, i + 1)
				if n == "(" then
					local j = consumeParen(input, i + 1)
					buffer ..= string.sub(input, i, j)
					wordStarted = true
					hasContent = true
					i = j + 1
				elseif n == "{" then
					local j = consumeBrace(input, i + 1)
					buffer ..= string.sub(input, i, j)
					wordStarted = true
					hasContent = true
					i = j + 1
				elseif n == "'" then
					flush(0)
					local text, nextIdx = readAnsiC(input, i + 1)
					table.insert(parts, { Text = text, Quote = 1 })
					wordStarted = true
					hasContent = true
					i = nextIdx
				else
					buffer ..= c
					wordStarted = true
					hasContent = true
					i += 1
				end
			elseif c == "`" then
				local j = consumeBacktick(input, i)
				buffer ..= string.sub(input, i, j)
				wordStarted = true
				hasContent = true
				i = j + 1
			elseif c == "(" and not wordStarted and string.sub(input, i + 1, i + 1) == "(" then
				local depth = 0
				local j = i
				while j <= len do
					local d = string.sub(input, j, j)
					if d == "\\" then
						j += 1
					elseif d == "(" then
						depth += 1
					elseif d == ")" then
						depth -= 1
						if depth == 0 then
							break
						end
					end
					j += 1
				end

				if j <= len and depth == 0 then
					flush(0)
					pushWord()
					table.insert(tokens, { Type = "arith", Text = string.sub(input, i + 2, j - 2) })
					i = j + 1
				else
					local op = matchOperator(input, i, true)
					pushOp(op or "(")
					i += #(op or "(")
				end
			elseif isOperatorStart(c) or (not wordStarted and string.match(c, "%d")) then
				local op = matchOperator(input, i, not wordStarted)
				if op then
					pushOp(op)
					i += #op
				else
					buffer ..= c
					wordStarted = true
					hasContent = true
					i += 1
				end
			else
				buffer ..= c
				wordStarted = true
				hasContent = true
				i += 1
			end
		elseif quote == 1 then
			if c == "'" then
				if buffer == "" then
					table.insert(parts, { Text = "", Quote = 1 })
				else
					flush(1)
				end
				quote = 0
				i += 1
			else
				buffer ..= c
				i += 1
			end
		else
			if c == '"' then
				if buffer == "" then
					table.insert(parts, { Text = "", Quote = 2 })
				else
					flush(2)
				end
				quote = 0
				i += 1
			elseif c == "\\" then
				local n = string.sub(input, i + 1, i + 1)
				if n == "$" or n == "`" or n == '"' or n == "\\" then
					flush(2)
					table.insert(parts, { Text = n, Quote = 1 })
					i += 2
				elseif n == "\n" then
					i += 2
				else
					buffer ..= c
					i += 1
				end
			elseif c == "$" then
				local n = string.sub(input, i + 1, i + 1)
				if n == "(" then
					local j = consumeParen(input, i + 1)
					buffer ..= string.sub(input, i, j)
					i = j + 1
				elseif n == "{" then
					local j = consumeBrace(input, i + 1)
					buffer ..= string.sub(input, i, j)
					i = j + 1
				else
					buffer ..= c
					i += 1
				end
			elseif c == "`" then
				local j = consumeBacktick(input, i)
				buffer ..= string.sub(input, i, j)
				i = j + 1
			else
				buffer ..= c
				i += 1
			end
		end
	end

	if quote ~= 0 then
		error(
			if quote == 1
				then "unexpected EOF while looking for matching `''"
				else "unexpected EOF while looking for matching `\"'",
			0
		)
	end

	flush(quote)
	pushWord()

	return tokens
end

--[=[
	Backwards-compatible helper: returns words and operators as plain strings.
	Used by autocomplete, which only needs the current word.

	@param input The input to process.
]=]
function Lexer.tokenize(input: string): { string }
	local out = {}
	for _, token in Lexer.lex(input) do
		if token.Type == "op" then
			table.insert(out, token.Value or "")
		else
			local text = {}
			for _, part in token.Parts or {} do
				table.insert(text, part.Text)
			end
			table.insert(out, table.concat(text))
		end
	end
	return out
end

--[=[
	Returns the plain text of a word token, ignoring quote modes.

	@param token The token to inspect.
]=]
function Lexer.wordText(token: Token?): string?
	if not token or token.Type ~= "word" then
		return nil
	end

	local text = {}
	for _, part in token.Parts or {} do
		table.insert(text, part.Text)
	end
	return table.concat(text)
end

return Lexer
