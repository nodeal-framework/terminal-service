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
	POSIX extended regular expressions.

	Supported: literals, `.`, `*`, `+`, `?`, `{m}`, `{m,}`, `{m,n}`, `^`, `$`,
	`[...]` (including POSIX classes), groups and captures, alternation,
	backreferences, and the shorthands `\d`, `\D`, `\w`, `\W`, `\s`, `\S`,
	`\b`, `\B`, `\<` and `\>`.

	Matching is leftmost-longest, like POSIX grep and sed.
]=]

local POSIX = {
	alpha = true,
	alnum = true,
	digit = true,
	lower = true,
	upper = true,
	space = true,
	blank = true,
	punct = true,
	xdigit = true,
	cntrl = true,
	graph = true,
	print = true,
	word = true,
}

local MATCH_LIMIT = 200000

local Regex = {}
Regex.__index = Regex

--// Parser //--

local Parser = {}
Parser.__index = Parser

--[=[
	Creates a parser over an extended regular expression.

	@param pattern The pattern to match.
	@param ignoreCase Whether matching ignores case.

	@return The new parser.
]=]
function Parser.new(pattern: string, ignoreCase: boolean)
	return setmetatable({
		Pattern = pattern,
		Pos = 1,
		Groups = 0,
		IgnoreCase = ignoreCase,
	}, Parser)
end

--[=[
	Returns a pattern character without consuming it.

	@param offset The offset from the current position.

	@return The resulting text.
]=]
function Parser:peek(offset: number?): string
	local index = self.Pos + (offset or 0)
	return string.sub(self.Pattern, index, index)
end

--[=[
	Consumes and returns one pattern character.

	@return The resulting text.
]=]
function Parser:take(): string
	local c = string.sub(self.Pattern, self.Pos, self.Pos)
	self.Pos += 1
	return c
end

--[=[
	Parses an alternation of concatenations.

	@return The parsed pattern node.
]=]
function Parser:parseAlt()
	local branches = { self:parseConcat() }

	while self:peek() == "|" do
		self.Pos += 1
		table.insert(branches, self:parseConcat())
	end

	if #branches == 1 then
		return branches[1]
	end
	return { T = "alt", Items = branches }
end

--[=[
	Parses a concatenation of repeated atoms.

	@return The parsed pattern node.
]=]
function Parser:parseConcat()
	local items = {}

	while true do
		local c = self:peek()
		if c == "" or c == "|" or c == ")" then
			break
		end
		table.insert(items, self:parseRepeat())
	end

	if #items == 1 then
		return items[1]
	end
	return { T = "concat", Items = items }
end

--[=[
	Parses a `{m}`, `{m,}` or `{m,n}` repetition bound.

	@param parser The parser to read from.

	@return The repetition bounds, or nil.
]=]
local function parseBounds(parser: Parser)
	local save = parser.Pos
	if parser:peek() ~= "{" then
		return nil
	end
	parser.Pos += 1

	--[=[
		Reads a decimal repetition count.

		@return The resulting number, or nil.
	]=]
	local function readNumber(): number?
		local start = parser.Pos
		while string.match(parser:peek(), "%d") do
			parser.Pos += 1
		end
		if parser.Pos == start then
			return nil
		end
		return tonumber(string.sub(parser.Pattern, start, parser.Pos - 1))
	end

	local min = readNumber()
	if not min then
		parser.Pos = save
		return nil
	end

	local max = min
	if parser:peek() == "," then
		parser.Pos += 1
		max = readNumber()
		if not max then
			max = math.huge
		end
	end

	if parser:peek() ~= "}" then
		parser.Pos = save
		return nil
	end
	parser.Pos += 1

	if max ~= math.huge and max < min then
		parser.Pos = save
		return nil
	end

	return min, max
end

--[=[
	Parses an atom followed by its repetition operators.

	@return The parsed pattern node.
]=]
function Parser:parseRepeat()
	local node = self:parseAtom()

	while true do
		local c = self:peek()
		if c == "*" then
			self.Pos += 1
			node = { T = "repeat", Node = node, Min = 0, Max = math.huge }
		elseif c == "+" then
			self.Pos += 1
			node = { T = "repeat", Node = node, Min = 1, Max = math.huge }
		elseif c == "?" then
			self.Pos += 1
			node = { T = "repeat", Node = node, Min = 0, Max = 1 }
		elseif c == "{" then
			local min, max = parseBounds(self)
			if min then
				node = { T = "repeat", Node = node, Min = min, Max = max }
			else
				break
			end
		else
			break
		end
	end

	return node
end

--[=[
	Creates one item of a bracket expression.

	@param kind The kind to classify.
	@param value The value to convert.

	@return The bracket-expression item.
]=]
local function classItem(kind: string, value)
	return { Kind = kind, Value = value }
end

--[=[
	Parses one character or range inside a bracket expression.

	@return The parsed class item.
]=]
function Parser:parseClassChar()
	local c = self:peek()

	if c == "\\" then
		self.Pos += 1
		local n = self:take()
		if n == "d" then
			return classItem("class", "digit")
		end
		if n == "D" then
			return classItem("notclass", "digit")
		end
		if n == "w" then
			return classItem("class", "word")
		end
		if n == "W" then
			return classItem("notclass", "word")
		end
		if n == "s" then
			return classItem("class", "space")
		end
		if n == "S" then
			return classItem("notclass", "space")
		end
		if n == "n" then
			return classItem("char", "\n")
		end
		if n == "t" then
			return classItem("char", "\t")
		end
		if n == "r" then
			return classItem("char", "\r")
		end
		if n == "f" then
			return classItem("char", "\f")
		end
		if n == "v" then
			return classItem("char", "\v")
		end
		if n == "b" then
			return classItem("char", "\b")
		end
		if n == "" then
			return classItem("char", "\\")
		end
		return classItem("char", n)
	end

	self.Pos += 1
	return classItem("char", c)
end

--[=[
	Parses a bracket expression.

	@return The parsed bracket expression.
]=]
function Parser:parseClass()
	local negate = false
	if self:peek() == "^" then
		negate = true
		self.Pos += 1
	end

	local items = {}
	local first = true

	while self.Pos <= #self.Pattern do
		local c = self:peek()
		if c == "]" and not first then
			self.Pos += 1
			break
		end
		first = false

		if c == "[" and self:peek(1) == ":" then
			local close = string.find(self.Pattern, ":]", self.Pos + 2, true)
			if close then
				local name = string.sub(self.Pattern, self.Pos + 2, close - 1)
				if POSIX[name] then
					table.insert(items, classItem("class", name))
				end
				self.Pos = close + 2
			else
				table.insert(items, classItem("char", self:take()))
			end
		else
			local item = self:parseClassChar()

			if
				item.Kind == "char"
				and self:peek() == "-"
				and self:peek(1) ~= "]"
				and self:peek(1) ~= ""
			then
				local save = self.Pos
				self.Pos += 1
				local high = self:parseClassChar()
				if high.Kind == "char" then
					table.insert(items, { Kind = "range", Lo = item.Value, Hi = high.Value })
				else
					table.insert(items, item)
					table.insert(items, classItem("char", "-"))
					table.insert(items, high)
				end
			else
				table.insert(items, item)
			end
		end
	end

	return { T = "class", Negate = negate, Items = items }
end

--[=[
	Parses an escape sequence inside a pattern.

	@return The parsed escape sequence.
]=]
function Parser:parseEscape()
	local n = self:take()

	if n == "d" then
		return { T = "class", Negate = false, Items = { classItem("class", "digit") } }
	end
	if n == "D" then
		return { T = "class", Negate = true, Items = { classItem("class", "digit") } }
	end
	if n == "w" then
		return { T = "class", Negate = false, Items = { classItem("class", "word") } }
	end
	if n == "W" then
		return { T = "class", Negate = true, Items = { classItem("class", "word") } }
	end
	if n == "s" then
		return { T = "class", Negate = false, Items = { classItem("class", "space") } }
	end
	if n == "S" then
		return { T = "class", Negate = true, Items = { classItem("class", "space") } }
	end
	if n == "b" then
		return { T = "boundary", Negate = false }
	end
	if n == "B" then
		return { T = "boundary", Negate = true }
	end
	if n == "<" then
		return { T = "wordstart" }
	end
	if n == ">" then
		return { T = "wordend" }
	end
	if n == "n" then
		return { T = "char", Char = "\n" }
	end
	if n == "t" then
		return { T = "char", Char = "\t" }
	end
	if n == "r" then
		return { T = "char", Char = "\r" }
	end
	if n == "f" then
		return { T = "char", Char = "\f" }
	end
	if n == "v" then
		return { T = "char", Char = "\v" }
	end
	if n == "" then
		return { T = "char", Char = "\\" }
	end
	if string.match(n, "%d") and n ~= "0" then
		return { T = "backref", Index = tonumber(n) }
	end
	return { T = "char", Char = n }
end

--[=[
	Parses a literal, class, group or anchor.

	@return The parsed pattern node.
]=]
function Parser:parseAtom()
	local c = self:peek()

	if c == "(" then
		self.Pos += 1
		self.Groups += 1
		local index = self.Groups
		local inner = self:parseAlt()
		if self:peek() == ")" then
			self.Pos += 1
		end
		return { T = "group", Index = index, Node = inner }
	elseif c == "[" then
		self.Pos += 1
		return self:parseClass()
	elseif c == "." then
		self.Pos += 1
		return { T = "any" }
	elseif c == "^" then
		self.Pos += 1
		return { T = "start" }
	elseif c == "$" then
		self.Pos += 1
		return { T = "end" }
	elseif c == "\\" then
		self.Pos += 1
		return self:parseEscape()
	end

	self.Pos += 1
	return { T = "char", Char = c }
end

--// Matching //--

--[=[
	Returns the character at a position, or an empty string.

	@param text The text to inspect.
	@param pos The text position.

	@return The resulting text.
]=]
local function charAt(text: string, pos: number): string
	return string.sub(text, pos, pos)
end

--[=[
	Checks whether a character is a word character.

	@param c The character to test.

	@return True when the condition holds.
]=]
local function isWordChar(c: string): boolean
	return c ~= "" and string.match(c, "[%w_]") ~= nil
end

--[=[
	Compares two characters, optionally ignoring case.

	@param a The first value.
	@param b The second value.
	@param ignoreCase Whether matching ignores case.

	@return True when the condition holds.
]=]
local function charEqual(a: string, b: string, ignoreCase: boolean): boolean
	if ignoreCase then
		return string.lower(a) == string.lower(b)
	end
	return a == b
end

--[=[
	Matches a POSIX character class.

	@param name The name to look up.
	@param c The character to test.

	@return True when the condition holds.
]=]
local function posixMatch(name: string, c: string): boolean
	if c == "" then
		return false
	end

	if name == "digit" then
		return string.match(c, "%d") ~= nil
	end
	if name == "word" then
		return string.match(c, "[%w_]") ~= nil
	end
	if name == "alpha" then
		return string.match(c, "%a") ~= nil
	end
	if name == "alnum" then
		return string.match(c, "[%a%d]") ~= nil
	end
	if name == "lower" then
		return string.match(c, "%l") ~= nil
	end
	if name == "upper" then
		return string.match(c, "%u") ~= nil
	end
	if name == "space" then
		return string.match(c, "%s") ~= nil
	end
	if name == "blank" then
		return c == " " or c == "\t"
	end
	if name == "punct" then
		return string.match(c, "%p") ~= nil
	end
	if name == "xdigit" then
		return string.match(c, "%x") ~= nil
	end
	if name == "graph" then
		local b = string.byte(c)
		return b ~= nil and b > 32 and b < 127
	end
	if name == "print" then
		local b = string.byte(c)
		return b ~= nil and b >= 32 and b < 127
	end
	if name == "cntrl" then
		local b = string.byte(c)
		return b ~= nil and (b < 32 or b == 127)
	end

	return false
end

--[=[
	Matches one bracket-expression item.

	@param item The class item to test.
	@param c The character to test.
	@param ignoreCase Whether matching ignores case.

	@return True when the condition holds.
]=]
local function classItemMatches(item, c: string, ignoreCase: boolean): boolean
	if c == "" then
		return false
	end

	if item.Kind == "char" then
		return charEqual(item.Value, c, ignoreCase)
	elseif item.Kind == "range" then
		local b = string.byte(c)
		if not b then
			return false
		end
		if b >= string.byte(item.Lo) and b <= string.byte(item.Hi) then
			return true
		end
		if ignoreCase then
			local lower = string.lower(c)
			local upper = string.upper(c)
			local lb = string.byte(lower)
			local ub = string.byte(upper)
			return (lb >= string.byte(item.Lo) and lb <= string.byte(item.Hi))
				or (ub >= string.byte(item.Lo) and ub <= string.byte(item.Hi))
		end
		return false
	elseif item.Kind == "class" then
		return posixMatch(item.Value, c)
	elseif item.Kind == "notclass" then
		return not posixMatch(item.Value, c)
	end

	return false
end

--[=[
	Matches a complete bracket expression.

	@param node The syntax tree node to evaluate.
	@param c The character to test.
	@param ignoreCase Whether matching ignores case.

	@return True when the condition holds.
]=]
local function classMatches(node, c: string, ignoreCase: boolean): boolean
	if c == "" then
		return false
	end

	local found = false
	for _, item in node.Items do
		if classItemMatches(item, c, ignoreCase) then
			found = true
			break
		end
	end

	if node.Negate then
		return not found
	end
	return found
end

--[=[
	Copies a capture table.

	@param captures The capture table.

	@return A copy of the capture table.
]=]
local function copyCaptures(captures)
	local copy = {}
	for key, value in captures do
		copy[key] = value
	end
	return copy
end

--[=[
	Checks whether a string occurs at a position.

	@param text The text to inspect.
	@param pos The text position.
	@param value The value to convert.
	@param ignoreCase Whether matching ignores case.

	@return True when the condition holds.
]=]
local function stringStartsWith(
	text: string,
	pos: number,
	value: string,
	ignoreCase: boolean
): boolean
	local candidate = string.sub(text, pos, pos + #value - 1)
	if #candidate ~= #value then
		return false
	end
	if ignoreCase then
		return string.lower(candidate) == string.lower(value)
	end
	return candidate == value
end

--[=[
	Matches a pattern node and emits every successful continuation.

	@param node The syntax tree node to evaluate.
	@param text The text to inspect.
	@param pos The text position.
	@param captures The capture table.
	@param emit The callback receiving each match.
	@param context The command context.

	@return True when a match was found.
]=]
local function match(node, text: string, pos: number, captures, emit, context)
	context.Steps += 1
	if context.Steps > MATCH_LIMIT then
		return
	end

	local kind = node.T
	local length = #text

	if kind == "char" then
		local c = charAt(text, pos)
		if c ~= "" and charEqual(c, node.Char, context.IgnoreCase) then
			emit(pos + 1, captures)
		end
	elseif kind == "any" then
		if pos <= length then
			emit(pos + 1, captures)
		end
	elseif kind == "class" then
		local c = charAt(text, pos)
		if c ~= "" and classMatches(node, c, context.IgnoreCase) then
			emit(pos + 1, captures)
		end
	elseif kind == "start" then
		if pos == 1 then
			emit(pos, captures)
		end
	elseif kind == "end" then
		if pos == length + 1 then
			emit(pos, captures)
		end
	elseif kind == "boundary" then
		local previous = if pos > 1 then charAt(text, pos - 1) else ""
		local next = charAt(text, pos)
		local boundary = isWordChar(previous) ~= isWordChar(next)
		if boundary ~= node.Negate then
			emit(pos, captures)
		end
	elseif kind == "wordstart" then
		local previous = if pos > 1 then charAt(text, pos - 1) else ""
		if not isWordChar(previous) and isWordChar(charAt(text, pos)) then
			emit(pos, captures)
		end
	elseif kind == "wordend" then
		local previous = if pos > 1 then charAt(text, pos - 1) else ""
		if isWordChar(previous) and not isWordChar(charAt(text, pos)) then
			emit(pos, captures)
		end
	elseif kind == "backref" then
		local value = captures[node.Index]
		if value and value ~= "" and stringStartsWith(text, pos, value, context.IgnoreCase) then
			emit(pos + #value, copyCaptures(captures))
		end
	elseif kind == "concat" then
		local items = node.Items
		--[=[
			Continues a sequence match at the next item.

			@param index The position to start at.
			@param at The current text position.
			@param caps The capture table to extend.
		]=]
		local function step(index: number, at: number, caps)
			if index > #items then
				emit(at, caps)
				return
			end
			match(items[index], text, at, caps, function(nextAt, nextCaps)
				step(index + 1, nextAt, nextCaps)
			end, context)
		end
		step(1, pos, captures)
	elseif kind == "alt" then
		for _, branch in node.Items do
			match(branch, text, pos, captures, emit, context)
		end
	elseif kind == "group" then
		match(node.Node, text, pos, captures, function(nextAt, nextCaps)
			local copy = copyCaptures(nextCaps)
			copy[node.Index] = string.sub(text, pos, nextAt - 1)
			emit(nextAt, copy)
		end, context)
	elseif kind == "repeat" then
		local minimum = node.Min
		local maximum = node.Max

		--[=[
			Continues a repetition match from a given count.

			@param count The count to apply.
			@param at The current text position.
			@param caps The capture table to extend.

			@return True when a repetition matched.
		]=]
		local function repeatFrom(count: number, at: number, caps)
			if context.Steps > MATCH_LIMIT then
				return
			end

			if count < maximum then
				match(node.Node, text, at, caps, function(nextAt, nextCaps)
					if nextAt == at then
						if count + 1 >= minimum then
							emit(nextAt, nextCaps)
						end
						return
					end
					repeatFrom(count + 1, nextAt, nextCaps)
				end, context)
			end

			if count >= minimum then
				emit(at, caps)
			end
		end

		repeatFrom(0, pos, captures)
	elseif kind == "empty" then
		emit(pos, captures)
	end
end

--// Public API //--

--[=[
	Translates a POSIX basic regular expression to ERE. In BRE, `\|`, `\(`, `\)`,
	`\+`, `\?` and `\{...\}` are operators and the unescaped forms are literals.

	@param pattern The pattern to match.
]=]
function Regex.breToEre(pattern: string): string
	local out = {}
	local i = 1
	local inSet = false

	while i <= #pattern do
		local c = string.sub(pattern, i, i)

		if c == "\\" then
			local n = string.sub(pattern, i + 1, i + 1)
			if
				not inSet
				and (
					n == "|"
					or n == "("
					or n == ")"
					or n == "+"
					or n == "?"
					or n == "{"
					or n == "}"
				)
			then
				table.insert(out, n)
			else
				table.insert(out, "\\" .. n)
			end
			i += 2
		elseif c == "[" then
			inSet = true
			table.insert(out, c)
			i += 1
		elseif c == "]" then
			inSet = false
			table.insert(out, c)
			i += 1
		elseif
			not inSet
			and (c == "(" or c == ")" or c == "|" or c == "+" or c == "?" or c == "{" or c == "}")
		then
			table.insert(out, "\\" .. c)
			i += 1
		else
			table.insert(out, c)
			i += 1
		end
	end

	return table.concat(out)
end

--[=[
	Compiles an ERE into an object with Find().

	@param pattern The pattern to match.
	@param ignoreCase Whether matching ignores case.
]=]
function Regex.compile(pattern: string, ignoreCase: boolean?)
	local parser = Parser.new(pattern, ignoreCase == true)
	local ast = parser:parseAlt()

	return setmetatable({
		Ast = ast,
		IgnoreCase = ignoreCase == true,
	}, Regex)
end

--[=[
	Finds the leftmost-longest match. Returns start, end, captures.

	@param text The text to inspect.
	@param init The position to start searching from.
]=]
function Regex:Find(text: string, init: number?)
	local start = math.max(1, init or 1)
	local context = { Steps = 0, IgnoreCase = self.IgnoreCase }

	for position = start, #text + 1 do
		local bestEnd = nil
		local bestCaptures = nil

		match(self.Ast, text, position, {}, function(finish, captures)
			if not bestEnd or finish > bestEnd then
				bestEnd = finish
				bestCaptures = captures
			end
		end, context)

		if bestEnd then
			return position, bestEnd - 1, bestCaptures
		end
		if context.Steps > MATCH_LIMIT then
			break
		end
	end

	return nil, nil, nil
end

--[=[
	Checks whether the pattern matches anywhere in the text.

	@param text The text to inspect.

	@return True when the condition holds.
]=]
function Regex:Test(text: string): boolean
	return self:Find(text) ~= nil
end

--[=[
	All non-overlapping matches (for grep -o).

	@param text The text to inspect.
]=]
function Regex:FindAll(text: string): { any }
	local matches = {}
	local init = 1

	while init <= #text do
		local s, e = self:Find(text, init)
		if not s then
			break
		end
		if e >= s then
			table.insert(matches, { s, e })
		end
		init = if e >= s then e + 1 else s + 1
	end

	return matches
end

return Regex
