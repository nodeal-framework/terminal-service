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
	Bash arithmetic expansion: `$((expr))`, `((expr))`, `let`.
	Supports the usual integer operators, assignment, ternary, ++/-- and short-circuiting.
]=]

type Node =
	{ kind: "num", value: number }
	| { kind: "var", name: string }
	| { kind: "unary", op: string, value: Node }
	| { kind: "binary", op: string, left: Node, right: Node }
	| { kind: "ternary", cond: Node, yes: Node, no: Node }
	| { kind: "assign", op: string, name: string, value: Node }
	| { kind: "incdec", op: string, name: string, prefix: boolean }

local BINARY_PRECEDENCE: { [string]: number } = {
	[","] = 1,
	["="] = 2,
	["+="] = 2,
	["-="] = 2,
	["*="] = 2,
	["/="] = 2,
	["%="] = 2,
	["<<="] = 2,
	[">>="] = 2,
	["&="] = 2,
	["|="] = 2,
	["^="] = 2,
	["**="] = 2,
	["?"] = 3,
	["||"] = 4,
	["&&"] = 5,
	["|"] = 6,
	["^"] = 7,
	["&"] = 8,
	["=="] = 9,
	["!="] = 9,
	["<"] = 10,
	["<="] = 10,
	[">"] = 10,
	[">="] = 10,
	["<<"] = 11,
	[">>"] = 11,
	["+"] = 12,
	["-"] = 12,
	["*"] = 13,
	["/"] = 13,
	["%"] = 13,
	["**"] = 14,
}

local RIGHT_ASSOC = {
	["="] = true,
	["+="] = true,
	["-="] = true,
	["*="] = true,
	["/="] = true,
	["%="] = true,
	["<<="] = true,
	[">>="] = true,
	["&="] = true,
	["|="] = true,
	["^="] = true,
	["**="] = true,
	["**"] = true,
	["?"] = true,
}

local ASSIGN_OPS = {
	["="] = true,
	["+="] = true,
	["-="] = true,
	["*="] = true,
	["/="] = true,
	["%="] = true,
	["<<="] = true,
	[">>="] = true,
	["&="] = true,
	["|="] = true,
	["^="] = true,
	["**="] = true,
}

local Arithmetic = {}

--[=[
	Splits an arithmetic expression into number, variable and operator tokens.

	@param text The text to inspect.

	@return The resulting list.
]=]
local function tokenize(text: string): { { kind: string, value: string } }
	local tokens = {}
	local i = 1
	local length = #text

	while i <= length do
		local c = string.sub(text, i, i)

		if string.match(c, "%s") then
			i += 1
		elseif string.match(c, "%d") then
			local start = i
			local base, digits = nil, nil

			local b, d = string.match(string.sub(text, i), "^(%d+)#([%w_]+)")
			if b then
				base = tonumber(b)
				digits = d
				i += #b + 1 + #d
			else
				local hex = string.match(string.sub(text, i), "^0[xX](%x+)")
				local bin = string.match(string.sub(text, i), "^0[bB]([01]+)")
				local oct = string.match(string.sub(text, i), "^0([0-7]+)")
				if hex then
					base, digits = 16, hex
					i += 2 + #hex
				elseif bin then
					base, digits = 2, bin
					i += 2 + #bin
				elseif oct then
					base, digits = 8, oct
					i += 1 + #oct
				else
					local dec = string.match(string.sub(text, i), "^%d+")
					base, digits = 10, dec
					i += #dec
				end
			end

			local value = 0
			if base and digits then
				for j = 1, #digits do
					local ch = string.sub(digits, j, j)
					local digit = tonumber(ch, 36)
					if digit and digit < base then
						value = value * base + digit
					end
				end
			end
			table.insert(tokens, { kind = "num", value = tostring(value) })
		elseif string.match(c, "[%a_]") then
			local name = string.match(string.sub(text, i), "^[%a_][%w_]*")
			table.insert(tokens, { kind = "var", value = name })
			i += #name
		elseif c == "$" then
			local name = string.match(string.sub(text, i), "^%$([%a_][%w_]*)")
			if name then
				table.insert(tokens, { kind = "var", value = name })
				i += 1 + #name
			else
				table.insert(tokens, { kind = "op", value = "$" })
				i += 1
			end
		else
			local three = string.sub(text, i, i + 2)
			local two = string.sub(text, i, i + 1)

			if three == "<<=" or three == ">>=" or three == "**=" then
				table.insert(tokens, { kind = "op", value = three })
				i += 3
			elseif
				two == "**"
				or two == "<<"
				or two == ">>"
				or two == "<="
				or two == ">="
				or two == "=="
				or two == "!="
				or two == "&&"
				or two == "||"
				or two == "++"
				or two == "--"
				or two == "+="
				or two == "-="
				or two == "*="
				or two == "/="
				or two == "%="
				or two == "&="
				or two == "|="
				or two == "^="
			then
				table.insert(tokens, { kind = "op", value = two })
				i += 2
			else
				table.insert(tokens, { kind = "op", value = c })
				i += 1
			end
		end
	end

	return tokens
end

local Parser = {}
Parser.__index = Parser

--[=[
	Creates a parser over a token list.

	@param tokens The token list to parse.

	@return The new parser.
]=]
function Parser.new(tokens)
	return setmetatable({ tokens = tokens, pos = 1 }, Parser)
end

--[=[
	Returns the next token value without consuming it.

	@return The resulting text, or nil.
]=]
function Parser:peek(): string?
	local t = self.tokens[self.pos]
	if t then
		return t.value
	end
	return nil
end

--[=[
	Returns the kind of the next token without consuming it.

	@return The resulting text, or nil.
]=]
function Parser:peekKind(): string?
	local t = self.tokens[self.pos]
	if t then
		return t.kind
	end
	return nil
end

--[=[
	Consumes and returns the next token.

	@return The consumed token.
]=]
function Parser:advance()
	local t = self.tokens[self.pos]
	self.pos += 1
	return t
end

--[=[
	Parses an expression at or above the given precedence.

	@param minPrec The minimum precedence to accept.

	@return The result, or nil.
]=]
function Parser:parseExpression(minPrec: number): Node?
	local left = self:parseUnary()
	if not left then
		return nil
	end

	while true do
		local op = self:peek()
		if not op then
			break
		end

		local prec = BINARY_PRECEDENCE[op]
		if not prec or prec < minPrec then
			break
		end

		self:advance()

		if op == "?" then
			local yes = self:parseExpression(1)
			if self:peek() ~= ":" then
				error("arithmetic: expected ':'", 0)
			end
			self:advance()
			local no = self:parseExpression(prec)
			left = { kind = "ternary", cond = left, yes = yes, no = no }
		elseif ASSIGN_OPS[op] then
			if left.kind ~= "var" then
				error("arithmetic: assignment to non-variable", 0)
			end
			local right = self:parseExpression(if RIGHT_ASSOC[op] then prec else prec + 1)
			left = { kind = "assign", op = op, name = left.name, value = right }
		else
			local nextMin = if RIGHT_ASSOC[op] then prec else prec + 1
			local right = self:parseExpression(nextMin)
			left = { kind = "binary", op = op, left = left, right = right }
		end
	end

	return left
end

--[=[
	Parses a prefix or postfix unary expression.

	@return The result, or nil.
]=]
function Parser:parseUnary(): Node?
	local op = self:peek()

	if op == "+" or op == "-" or op == "!" or op == "~" then
		self:advance()
		local value = self:parseUnary()
		return { kind = "unary", op = op, value = value }
	elseif op == "++" or op == "--" then
		self:advance()
		local value = self:parseUnary()
		if not value or value.kind ~= "var" then
			error("arithmetic: ++/-- needs a variable", 0)
		end
		return { kind = "incdec", op = op, name = value.name, prefix = true }
	end

	local node = self:parsePrimary()
	if not node then
		return nil
	end

	local post = self:peek()
	if post == "++" or post == "--" then
		if node.kind ~= "var" then
			error("arithmetic: ++/-- needs a variable", 0)
		end
		self:advance()
		node = { kind = "incdec", op = post, name = node.name, prefix = false }
	end

	return node
end

--[=[
	Parses a number, variable or parenthesised expression.

	@return The result, or nil.
]=]
function Parser:parsePrimary(): Node?
	local kind = self:peekKind()
	local value = self:peek()

	if not kind then
		return nil
	end

	if kind == "num" then
		self:advance()
		return { kind = "num", value = tonumber(value) or 0 }
	elseif kind == "var" then
		self:advance()
		return { kind = "var", name = value }
	elseif value == "(" then
		self:advance()
		local node = self:parseExpression(1)
		if self:peek() ~= ")" then
			error("arithmetic: expected ')'", 0)
		end
		self:advance()
		return node
	else
		error(`arithmetic: unexpected token '{value}'`, 0)
	end
end

--[=[
	Divides two integers and truncates the result toward zero.

	@param a The first value.
	@param b The second value.

	@return The resulting number.
]=]
local function trunc(a: number, b: number): number
	if b == 0 then
		error("division by 0", 0)
	end
	local q = a / b
	if q >= 0 then
		return math.floor(q)
	end
	return math.ceil(q)
end

--[=[
	Converts a value to a number, defaulting to zero.

	@param value The value to convert.

	@return The resulting number.
]=]
local function toNumber(value: any): number
	local n = tonumber(value)
	if not n then
		return 0
	end
	return n
end

local Evaluator = {}

--[=[
	Evaluates one arithmetic syntax node.

	@param node The syntax tree node to evaluate.
	@param shell The shell instance.

	@return The resulting number.
]=]
local function evalNode(node: Node, shell): number
	if node.kind == "num" then
		return node.value
	elseif node.kind == "var" then
		return toNumber(shell:GetVar(node.name))
	elseif node.kind == "unary" then
		local v = evalNode(node.value, shell)
		if node.op == "+" then
			return v
		end
		if node.op == "-" then
			return -v
		end
		if node.op == "!" then
			if v == 0 then
				return 1
			end
			return 0
		end
		if node.op == "~" then
			return -v - 1
		end
		return 0
	elseif node.kind == "ternary" then
		if evalNode(node.cond, shell) ~= 0 then
			return evalNode(node.yes, shell)
		end
		return evalNode(node.no, shell)
	elseif node.kind == "assign" then
		local value = evalNode(node.value, shell)
		local current = toNumber(shell:GetVar(node.name))
		local op = string.sub(node.op, 1, #node.op - 1)
		local result = value

		if op == "+" then
			result = current + value
		elseif op == "-" then
			result = current - value
		elseif op == "*" then
			result = current * value
		elseif op == "/" then
			result = trunc(current, value)
		elseif op == "%" then
			result = current - trunc(current, value) * value
		elseif op == "<<" then
			result = current * 2 ^ value
		elseif op == ">>" then
			result = math.floor(current / 2 ^ value)
		elseif op == "&" then
			result = bit32.band(current, value)
		elseif op == "|" then
			result = bit32.bor(current, value)
		elseif op == "^" then
			result = bit32.bxor(current, value)
		elseif op == "**" then
			result = current ^ value
		end

		shell:SetVar(node.name, tostring(result))
		return result
	elseif node.kind == "incdec" then
		local current = toNumber(shell:GetVar(node.name))
		local result
		if node.op == "++" then
			result = current + 1
		else
			result = current - 1
		end
		shell:SetVar(node.name, tostring(result))
		if node.prefix then
			return result
		end
		return current
	elseif node.kind == "binary" then
		local op = node.op

		if op == "," then
			evalNode(node.left, shell)
			return evalNode(node.right, shell)
		elseif op == "&&" then
			if evalNode(node.left, shell) == 0 then
				return 0
			end
			if evalNode(node.right, shell) ~= 0 then
				return 1
			end
			return 0
		elseif op == "||" then
			if evalNode(node.left, shell) ~= 0 then
				return 1
			end
			if evalNode(node.right, shell) ~= 0 then
				return 1
			end
			return 0
		end

		local a = evalNode(node.left, shell)
		local b = evalNode(node.right, shell)

		if op == "+" then
			return a + b
		elseif op == "-" then
			return a - b
		elseif op == "*" then
			return a * b
		elseif op == "/" then
			return trunc(a, b)
		elseif op == "%" then
			return a - trunc(a, b) * b
		elseif op == "**" then
			return a ^ b
		elseif op == "<<" then
			return a * 2 ^ b
		elseif op == ">>" then
			return math.floor(a / 2 ^ b)
		elseif op == "&" then
			return bit32.band(a, b)
		elseif op == "|" then
			return bit32.bor(a, b)
		elseif op == "^" then
			return bit32.bxor(a, b)
		elseif op == "==" then
			if a == b then
				return 1
			end
			return 0
		elseif op == "!=" then
			if a ~= b then
				return 1
			end
			return 0
		elseif op == "<" then
			if a < b then
				return 1
			end
			return 0
		elseif op == "<=" then
			if a <= b then
				return 1
			end
			return 0
		elseif op == ">" then
			if a > b then
				return 1
			end
			return 0
		elseif op == ">=" then
			if a >= b then
				return 1
			end
			return 0
		end
	end

	return 0
end

--[=[
	Evaluates an arithmetic expression and returns the integer result.

	@param expression The expression to evaluate.
	@param shell The shell instance.
]=]
function Arithmetic.eval(expression: string, shell): number
	local tokens = tokenize(expression)
	if #tokens == 0 then
		return 0
	end

	local parser = Parser.new(tokens)
	local node = parser:parseExpression(1)

	if parser.pos <= #tokens then
		error(`arithmetic: unexpected token '{parser:peek()}'`, 0)
	end

	return evalNode(node, shell)
end

return Arithmetic
