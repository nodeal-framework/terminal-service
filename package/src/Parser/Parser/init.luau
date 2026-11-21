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
	Recursive-descent parser for the Bash subset this terminal understands.

	Precedence, low to high: `;` / `&`, then `&&` / `||` (left-associative),
	then `|` / `|&`, then a simple or compound command.

	Words are left unexpanded in the AST: expansion happens per command at execution
	time, exactly as in Bash. That is what makes `x="|"; echo a $x b` print `a | b`
	instead of creating a pipe.
]=]

local Lexer = require(script.Parent.Parent.Lexer)

local Parser = {}

local RESERVED = {
	["if"] = true, ["then"] = true, ["elif"] = true, ["else"] = true, ["fi"] = true,
	["for"] = true, ["in"] = true, ["do"] = true, ["done"] = true,
	["while"] = true, ["until"] = true, ["select"] = true,
	["case"] = true, ["esac"] = true, ["function"] = true,
	["time"] = true, ["!"] = true, ["{"] = true, ["}"] = true,
}

local REDIRECT_OPS = {
	[">"] = true, [">>"] = true, [">|"] = true,
	["<"] = true, ["<>"] = true,
	["&>"] = true, ["&>>"] = true,
	["<<<"] = true, ["<<"] = true, ["<<-"] = true,
	[">&"] = true, ["<&"] = true,
}

local function wordText(token): string?
	if not token or token.Type ~= "word" then
		return nil
	end
	local out = {}
	for _, part in token.Parts or {} do
		table.insert(out, part.Text)
	end
	return table.concat(out)
end

local function isReserved(token, name: string): boolean
	return token ~= nil and token.Type == "word" and token.Quoted ~= true and wordText(token) == name
end

local function isOp(token, value: string): boolean
	return token ~= nil and token.Type == "op" and token.Value == value
end

local function isRedirectOp(value: string): boolean
	if REDIRECT_OPS[value] then return true end
	return string.match(value, "^%d+[<>]") ~= nil or string.match(value, "^%d+>>$") ~= nil
end

local function parseFd(op: string): (number, string)
	local fd, rest = string.match(op, "^(%d+)(.*)$")
	if fd then
		return tonumber(fd) or 1, rest
	end
	return 1, op
end

local P = {}
P.__index = P

function P.new(tokens: { any })
	return setmetatable({ tokens = tokens, pos = 1 }, P)
end

function P:peek(offset: number?)
	local index = self.pos + (offset or 0)
	return self.tokens[index]
end

function P:advance()
	local token = self.tokens[self.pos]
	self.pos += 1
	return token
end

function P:atEnd(): boolean
	return self.pos > #self.tokens
end

function P:expectWord(what: string?)
	local token = self:peek()
	if not token or token.Type ~= "word" then
		error(`syntax error: expected {what or "word"}`, 0)
	end
	self:advance()
	return token
end

function P:expectOp(value: string)
	local token = self:peek()
	if not isOp(token, value) then
		local got = if token then (if token.Type == "op" then token.Value else wordText(token)) else "end of line"
		error(`syntax error: expected '{value}', got '{got}'`, 0)
	end
	self:advance()
	return token
end

function P:expectReserved(name: string)
	local token = self:peek()
	if not isReserved(token, name) then
		local got = if token then (if token.Type == "op" then token.Value else wordText(token)) else "end of line"
		error(`syntax error: expected '{name}', got '{got}'`, 0)
	end
	self:advance()
	return token
end

function P:atStop(stops, stopOps): boolean
	local token = self:peek()
	if not token then return true end
	if token.Type == "op" and stopOps and stopOps[token.Value] then return true end
	if token.Type == "word" and stops and stops[wordText(token)] and not token.Quoted then return true end
	return false
end

--// Redirects //--

function P:parseAutoRedirects()
	local redirects = nil

	while true do
		local token = self:peek()
		if not token or token.Type ~= "op" or not isRedirectOp(token.Value) then
			break
		end

		local opToken = self:advance()
		local op = opToken.Value
		local target = self:expectWord("redirection target")
		local fd, kind = parseFd(op)

		redirects = redirects or {}
		table.insert(redirects, { Fd = fd, Op = kind, Target = target, HereDoc = opToken.HereDoc })
	end

	return redirects
end

--// Simple command //--

local function splitAssignment(token)
	if not token or token.Type ~= "word" then return nil end

	local name = {}
	local value = {}
	local found = false

	for _, part in token.Parts or {} do
		if not found and part.Quote == 0 then
			local index = string.find(part.Text, "=", 1, true)
			if index then
				table.insert(name, string.sub(part.Text, 1, index - 1))
				local rest = string.sub(part.Text, index + 1)
				if rest ~= "" then
					table.insert(value, { Text = rest, Quote = 0 })
				end
				found = true
			else
				table.insert(name, part.Text)
			end
		elseif found then
			table.insert(value, part)
		else
			table.insert(name, part.Text)
		end
	end

	local nameText = table.concat(name)
	local append = false
	if string.sub(nameText, -1) == "+" then
		append = true
		nameText = string.sub(nameText, 1, -2)
	end
	if not found or not string.match(nameText, "^[%a_][%w_]*$") then
		return nil
	end

	return {
		Name = nameText,
		Value = { Type = "word", Parts = value, Quoted = false },
		Append = append,
	}
end

function P:tryParseArrayAssignment()
	local token = self:peek()
	if not token or token.Type ~= "word" or token.Quoted == true then
		return nil
	end

	local text = wordText(token)
	local name, plus = string.match(text or "", "^([%a_][%w_]*)(%+?)=$")
	if not name or not isOp(self:peek(1), "(") then
		return nil
	end

	self:advance() -- name=
	self:advance() -- (

	local values = {}
	local depth = 1

	while not self:atEnd() and depth > 0 do
		local current = self:peek()
		if isOp(current, ")") then
			depth -= 1
			self:advance()
		elseif isOp(current, "(") then
			depth += 1
			self:advance()
		elseif isOp(current, ";") then
			self:advance()
		elseif isOp(current, "&&") or isOp(current, "||") then
			break
		else
			table.insert(values, current)
			self:advance()
		end
	end

	return {
		Name = name,
		Array = values,
		Append = plus == "+",
	}
end

function P:parseSimple()
	local words = {}
	local assignments = {}
	local redirects = {}

	while true do
		local token = self:peek()
		if not token then break end

		if token.Type == "op" then
			if isRedirectOp(token.Value) then
				local opToken = self:advance()
				local op = opToken.Value
				local target = self:expectWord("redirection target")
				local fd, kind = parseFd(op)
				table.insert(redirects, { Fd = fd, Op = kind, Target = target, HereDoc = opToken.HereDoc })
			else
				break
			end
		else
			if #words == 0 then
				local arrayAssignment = self:tryParseArrayAssignment()
				if arrayAssignment then
					table.insert(assignments, arrayAssignment)
					continue
				end

				local assignment = splitAssignment(token)
				if assignment then
					table.insert(assignments, assignment)
					self:advance()
					continue
				end
			end

			table.insert(words, token)
			self:advance()
		end
	end

	if #words == 0 and #assignments == 0 and #redirects == 0 then
		return nil
	end

	return {
		type = "Simple",
		Words = words,
		Assignments = assignments,
		Redirects = redirects,
	}
end

--// Compound commands //--

function P:parseIf()
	self:expectReserved("if")
	local branches = {}

	while true do
		local condition = self:parseList({ ["then"] = true }, nil)
		self:expectReserved("then")
		local body = self:parseList({ ["elif"] = true, ["else"] = true, ["fi"] = true }, nil)
		table.insert(branches, { Condition = condition, Body = body })

		if isReserved(self:peek(), "elif") then
			self:advance()
		else
			break
		end
	end

	local elseBody = nil
	if isReserved(self:peek(), "else") then
		self:advance()
		elseBody = self:parseList({ ["fi"] = true }, nil)
	end

	self:expectReserved("fi")
	return { type = "If", Branches = branches, Else = elseBody }
end

local function splitArithmeticFor(text: string): { string }
	local parts = {}
	local depth = 0
	local start = 1

	for i = 1, #text do
		local c = string.sub(text, i, i)
		if c == "(" then
			depth += 1
		elseif c == ")" then
			depth = math.max(0, depth - 1)
		elseif c == ";" and depth == 0 then
			table.insert(parts, string.match(string.sub(text, start, i - 1), "^%s*(.-)%s*$"))
			start = i + 1
		end
	end

	table.insert(parts, string.match(string.sub(text, start), "^%s*(.-)%s*$"))
	while #parts < 3 do
		table.insert(parts, "")
	end
	return parts
end

function P:parseFor()
	self:expectReserved("for")

	if self:peek() and self:peek().Type == "arith" then
		local parts = splitArithmeticFor(self:advance().Text or "")
		if isOp(self:peek(), ";") then
			self:advance()
		end
		self:expectReserved("do")
		local body = self:parseList({ ["done"] = true }, nil)
		self:expectReserved("done")
		return {
			type = "ForArith",
			Init = parts[1],
			Cond = parts[2],
			Step = parts[3],
			Body = body,
		}
	end

	local nameToken = self:expectWord("loop variable")
	local name = wordText(nameToken)
	if not string.match(name or "", "^[%a_][%w_]*$") then
		error("syntax error: invalid loop variable", 0)
	end

	local words = {}
	local hasIn = false

	if isReserved(self:peek(), "in") then
		hasIn = true
		self:advance()
		while not self:atEnd() do
			local token = self:peek()
			if isOp(token, ";") or isReserved(token, "do") then break end
			table.insert(words, self:expectWord())
		end
	end

	while isOp(self:peek(), ";") do
		self:advance()
	end

	self:expectReserved("do")
	local body = self:parseList({ ["done"] = true }, nil)
	self:expectReserved("done")

	return { type = "For", Name = name, Words = words, HasIn = hasIn, Body = body }
end

function P:parseWhile(untilLoop: boolean)
	self:advance() -- while / until
	local condition = self:parseList({ ["do"] = true }, nil)
	self:expectReserved("do")
	local body = self:parseList({ ["done"] = true }, nil)
	self:expectReserved("done")
	return { type = "While", Until = untilLoop, Condition = condition, Body = body }
end

function P:parseCase()
	self:expectReserved("case")
	local word = self:expectWord("case word")
	self:expectReserved("in")

	local items = {}

	while not self:atEnd() and not isReserved(self:peek(), "esac") do
		while isOp(self:peek(), ";") do
			self:advance()
		end
		if self:atEnd() or isReserved(self:peek(), "esac") then
			break
		end

		if isOp(self:peek(), "(") then
			self:advance()
		end

		local patterns = {}
		while true do
			table.insert(patterns, self:expectWord("case pattern"))
			if isOp(self:peek(), "|") then
				self:advance()
				while isOp(self:peek(), ";") do self:advance() end
			else
				break
			end
		end

		self:expectOp(")")

		local body = self:parseList(
			{ ["esac"] = true },
			{ [";;"] = true, [";&"] = true, [";;&"] = true }
		)

		local terminator = ";;"
		local token = self:peek()
		if token and token.Type == "op" and (token.Value == ";;" or token.Value == ";&" or token.Value == ";;&") then
			terminator = self:advance().Value
		end

		table.insert(items, { Patterns = patterns, Body = body, Terminator = terminator })
	end

	self:expectReserved("esac")
	return { type = "Case", Word = word, Items = items }
end

function P:parseFunction()
	local nameToken = self:expectWord("function name")
	local name = wordText(nameToken)

	if isOp(self:peek(), "(") then
		self:advance()
		self:expectOp(")")
	end

	while isOp(self:peek(), ";") do
		self:advance()
	end

	local body = self:parseCommand()
	if not body then
		error(`syntax error: function '{name}' has no body`, 0)
	end

	return { type = "Function", Name = name, Body = body }
end

function P:parseDoubleBracket()
	local words = { self:advance() }

	while not self:atEnd() do
		local token = self:advance()
		if token.Type == "word" and wordText(token) == "]]" then
			table.insert(words, token)
			break
		elseif token.Type == "op" then
			table.insert(words, {
				Type = "word",
				Parts = { { Text = token.Value, Quote = 0 } },
				Quoted = false,
			})
		else
			table.insert(words, token)
		end
	end

	local redirects = self:parseAutoRedirects() or {}
	return { type = "Simple", Words = words, Assignments = {}, Redirects = redirects }
end

function P:withRedirects(node)
	if not node then
		return node
	end

	local redirects = self:parseAutoRedirects()
	if redirects and #redirects > 0 then
		node.Redirects = redirects
	end

	return node
end

function P:parseCommand(): any
	local token = self:peek()
	if not token then return nil end

	if token.Type == "word" and wordText(token) == "[[" then
		return self:parseDoubleBracket()
	end

	if isReserved(token, "if") then
		return self:withRedirects(self:parseIf())
	elseif token.Type == "arith" then
		self:advance()
		return self:withRedirects({ type = "Arith", Expression = token.Text or "" })
	elseif isReserved(token, "for") then
		return self:withRedirects(self:parseFor())
	elseif isReserved(token, "while") then
		return self:withRedirects(self:parseWhile(false))
	elseif isReserved(token, "until") then
		return self:withRedirects(self:parseWhile(true))
	elseif isReserved(token, "case") then
		return self:withRedirects(self:parseCase())
	elseif isReserved(token, "function") then
		self:advance()
		return self:parseFunction()
	elseif isReserved(token, "{") then
		self:advance()
		local body = self:parseList({ ["}"] = true }, nil)
		self:expectReserved("}")
		local node = { type = "Group", Body = body }
		local redirects = self:parseAutoRedirects()
		if redirects then node.Redirects = redirects end
		return node
	elseif isOp(token, "(") then
		self:advance()
		local body = self:parseList(nil, { [")"] = true })
		self:expectOp(")")
		local node = { type = "Subshell", Body = body }
		local redirects = self:parseAutoRedirects()
		if redirects then node.Redirects = redirects end
		return node
	end

	-- name() { ... }
	if token.Type == "word" then
		local second = self:peek(1)
		local third = self:peek(2)
		local text = wordText(token) or ""
		if isOp(second, "(") and isOp(third, ")") and not string.match(text, "^[%a_][%w_]*%+?=$") then
			return self:parseFunction()
		end
	end

	local node = self:parseSimple()
	if not node then return nil end

	local redirects = self:parseAutoRedirects()
	if redirects then
		for _, redirect in redirects do
			table.insert(node.Redirects, redirect)
		end
	end

	return node
end

--// Lists //--

function P:parsePipeline()
	local negate = false

	while isReserved(self:peek(), "!") do
		negate = not negate
		self:advance()
	end

	local timed = false
	if isReserved(self:peek(), "time") then
		timed = true
		self:advance()
		if isReserved(self:peek(), "-p") then
			self:advance()
		end
	end

	local commands = {}
	local pipeErr = {}

	while true do
		local command = self:parseCommand()
		if not command then
			error("syntax error: expected command", 0)
		end
		table.insert(commands, command)

		local token = self:peek()
		if isOp(token, "|") then
			table.insert(pipeErr, false)
			self:advance()
			while isOp(self:peek(), ";") do self:advance() end
		elseif isOp(token, "|&") then
			table.insert(pipeErr, true)
			self:advance()
			while isOp(self:peek(), ";") do self:advance() end
		else
			break
		end
	end

	local node = {
		type = "Pipeline",
		Commands = commands,
		Negate = negate,
		PipeErr = pipeErr,
		Time = timed,
	}

	return node
end

function P:parseAndOr()
	local node = self:parsePipeline()

	while true do
		local token = self:peek()
		if isOp(token, "&&") or isOp(token, "||") then
			local op = self:advance().Value
			while isOp(self:peek(), ";") do self:advance() end
			local right = self:parsePipeline()
			node = { type = "AndOr", Op = op, Left = node, Right = right }
		else
			break
		end
	end

	return node
end

function P:parseList(stops, stopOps)
	local node = nil

	while true do
		local token = self:peek()
		if not token then break end
		if self:atStop(stops, stopOps) then break end

		if isOp(token, ";") or isOp(token, "&") then
			local op = self:advance().Value
			while isOp(self:peek(), ";") do
				self:advance()
			end

			if self:atStop(stops, stopOps) or not self:peek() then
				if op == "&" and node then
					node = { type = "List", Op = "&", Left = node, Right = nil }
				end
				break
			end

			if not node then
				continue
			end

			local right = self:parseAndOr()
			if not right then break end
			node = { type = "List", Op = op, Left = node, Right = right }
		else
			local command = self:parseAndOr()
			if not command then break end
			if not node then
				node = command
			else
				node = { type = "List", Op = ";", Left = node, Right = command }
			end
		end
	end

	return node
end

--[=[
	Parses a token list into an AST. Returns nil for an empty line.
]=]
function Parser.parse(tokens: { any }): any?
	if #tokens == 0 then return nil end

	local parser = P.new(tokens)
	local ast = parser:parseList(nil, nil)

	if not parser:atEnd() then
		local token = parser:peek()
		local got = if token.Type == "op" then token.Value else wordText(token)
		error(`syntax error near unexpected token '{got}'`, 0)
	end

	return ast
end

return Parser
