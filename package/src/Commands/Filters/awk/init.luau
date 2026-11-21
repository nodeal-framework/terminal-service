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
	awk: a practical subset.

	Supported: BEGIN/END, pattern/action rules, print/printf, fields, NF/NR/FNR,
	FS/OFS/ORS, arithmetic, comparisons, logical operators, regex matching,
	assignments, if/else, while, for, break/continue/next/exit, and the common
	string/number functions. Custom awk functions and arrays beyond split() are
	not implemented yet.
]=]

local Getopt = require(script.Parent.Parent.Parent.Parent.Classes.Getopt)
local Regex = require(script.Parent.Parent.Parent.Parent.Classes.Regex)
local Text = require(script.Parent.Parent.Parent.Parent.Classes.Text)

local function tokenize(program: string): (any?, string?)
	local tokens = {}
	local i = 1
	local expectOperand = true

	local function push(kind, value)
		table.insert(tokens, { Kind = kind, Value = value })
	end

	while i <= #program do
		local c = string.sub(program, i, i)

		if string.match(c, "%s") then
			if c == "\n" then push("op", ";") end
			i += 1
		elseif c == "#" then
			local newline = string.find(program, "\n", i, true)
			i = if newline then newline + 1 else #program + 1
		elseif c == "\"" then
			local out = {}
			i += 1
			while i <= #program do
				local d = string.sub(program, i, i)
				if d == "\\" then
					local n = string.sub(program, i + 1, i + 1)
					local map = { n = "\n", t = "\t", r = "\r", ["\\"] = "\\", ["\""] = "\"", ["/"] = "/" }
					table.insert(out, map[n] or n)
					i += 2
				elseif d == "\"" then
					i += 1
					break
				else
					table.insert(out, d)
					i += 1
				end
			end
			push("str", table.concat(out))
			expectOperand = false
		elseif c == "/" and expectOperand then
			local out = {}
			i += 1
			while i <= #program do
				local d = string.sub(program, i, i)
				if d == "\\" and string.sub(program, i + 1, i + 1) == "/" then
					table.insert(out, "/")
					i += 2
				elseif d == "/" then
					i += 1
					break
				else
					table.insert(out, d)
					i += 1
				end
			end
			push("regex", table.concat(out))
			expectOperand = false
		elseif string.match(c, "%d") or (c == "." and string.match(string.sub(program, i + 1, i + 1), "%d")) then
			local number = string.match(string.sub(program, i), "^%d*%.?%d+")
			push("num", tonumber(number))
			i += #number
			expectOperand = false
		elseif string.match(c, "[%a_]") then
			local name = string.match(string.sub(program, i), "^[%a_][%w_]*")
			push("id", name)
			i += #name
			expectOperand = not (name == "BEGIN" or name == "END" or name == "print" or name == "printf"
				or name == "if" or name == "else" or name == "while" or name == "for" or name == "do"
				or name == "break" or name == "continue" or name == "next" or name == "exit")
		else
			local two = string.sub(program, i, i + 1)
			if two == "==" or two == "!=" or two == "<=" or two == ">=" or two == "&&"
				or two == "||" or two == "!~" or two == "+=" or two == "-=" or two == "*="
				or two == "/=" or two == "%=" or two == "^=" or two == "++" or two == "--" then
				push("op", two)
				i += 2
				expectOperand = true
			else
				push("op", c)
				i += 1
				expectOperand = not (c == ")" or c == "]" or c == "}")
			end
		end
	end

	push("eof", "")
	return tokens, nil
end

local P = {}
P.__index = P

function P.new(tokens)
	return setmetatable({ Tokens = tokens, Pos = 1 }, P)
end

function P:peek()
	return self.Tokens[self.Pos]
end

function P:advance()
	local token = self.Tokens[self.Pos]
	self.Pos += 1
	return token
end

function P:matchValue(value: string): boolean
	local token = self:peek()
	if token and token.Value == value then
		self:advance()
		return true
	end
	return false
end

function P:expect(value: string)
	if not self:matchValue(value) then
		local token = self:peek()
		error(`awk: expected '{value}', got '{token and token.Value or "EOF"}'`, 0)
	end
end

local BINARY = {
	["="] = 1, ["+="] = 1, ["-="] = 1, ["*="] = 1, ["/="] = 1, ["%="] = 1, ["^="] = 1,
	["?"] = 2,
	["||"] = 3,
	["&&"] = 4,
	["=="] = 6, ["!="] = 6, ["<"] = 6, ["<="] = 6, [">"] = 6, [">="] = 6, ["~"] = 6, ["!~"] = 6,
	["+"] = 8, ["-"] = 8,
	["*"] = 9, ["/"] = 9, ["%"] = 9,
	["^"] = 10,
}

local RIGHT = { ["="] = true, ["+="] = true, ["-="] = true, ["*="] = true, ["/="] = true, ["%="] = true, ["^="] = true, ["^"] = true, ["?"] = true }

local function startsExpression(token): boolean
	if not token then return false end
	if token.Kind == "num" or token.Kind == "str" or token.Kind == "regex" or token.Kind == "id" then return true end
	return token.Value == "(" or token.Value == "$" or token.Value == "!" or token.Value == "-" or token.Value == "+"
		or token.Value == "++" or token.Value == "--"
end

function P:parseExpression(minPrec: number)
	local left = self:parseUnary()

	while true do
		local token = self:peek()
		if not token or token.Kind == "eof" then break end

		local op = token.Value
		local prec = BINARY[op]

		if prec and prec >= minPrec then
			self:advance()

			if op == "?" then
				local yes = self:parseExpression(1)
				self:expect(":")
				local no = self:parseExpression(prec)
				left = { Kind = "ternary", Cond = left, Yes = yes, No = no }
			elseif op == "=" or op == "+=" or op == "-=" or op == "*=" or op == "/=" or op == "%=" or op == "^=" then
				local right = self:parseExpression(prec)
				left = { Kind = "assign", Op = op, Target = left, Value = right }
			else
				local right = self:parseExpression(if RIGHT[op] then prec else prec + 1)
				left = { Kind = "binary", Op = op, Left = left, Right = right }
			end
		elseif startsExpression(token) and minPrec <= 7 then
			local right = self:parseUnary()
			left = { Kind = "concat", Left = left, Right = right }
		else
			break
		end
	end

	return left
end

function P:parseUnary()
	local token = self:peek()
	if not token then error("awk: unexpected end of program", 0) end

	if token.Value == "!" or token.Value == "-" or token.Value == "+" then
		self:advance()
		return { Kind = "unary", Op = token.Value, Value = self:parseUnary() }
	elseif token.Value == "++" or token.Value == "--" then
		self:advance()
		return { Kind = "incdec", Op = token.Value, Target = self:parseUnary(), Prefix = true }
	end

	local node = self:parsePrimary()

	local post = self:peek()
	if post and (post.Value == "++" or post.Value == "--") then
		self:advance()
		node = { Kind = "incdec", Op = post.Value, Target = node, Prefix = false }
	end

	return node
end

function P:parsePrimary()
	local token = self:advance()
	if not token then error("awk: unexpected end of program", 0) end

	if token.Kind == "num" or token.Kind == "str" then
		return { Kind = token.Kind, Value = token.Value }
	elseif token.Kind == "regex" then
		return { Kind = "regex", Pattern = token.Value }
	elseif token.Value == "(" then
		local node = self:parseExpression(1)
		self:expect(")")
		return node
	elseif token.Value == "$" then
		local index = self:parsePrimary()
		return { Kind = "field", Index = index }
	elseif token.Kind == "id" then
		if self:matchValue("(") then
			local args = {}
			if not self:matchValue(")") then
				while true do
					table.insert(args, self:parseExpression(1))
					if self:matchValue(",") then continue end
					self:expect(")")
					break
				end
			end
			return { Kind = "call", Name = token.Value, Args = args }
		end
		if self:matchValue("[") then
			local index = self:parseExpression(1)
			self:expect("]")
			return { Kind = "array", Name = token.Value, Index = index }
		end
		return { Kind = "var", Name = token.Value }
	end

	error(`awk: unexpected token '{token.Value}'`, 0)
end

function P:parseBlock()
	self:expect("{")
	local body = {}
	while true do
		local token = self:peek()
		if not token or token.Kind == "eof" then break end
		if token.Value == "}" then
			self:advance()
			break
		end
		if token.Value == ";" then
			self:advance()
			continue
		end
		table.insert(body, self:parseStatement())
	end
	return { Kind = "block", Body = body }
end

function P:parseStatement()
	local token = self:peek()
	if not token then error("awk: unexpected end of program", 0) end

	if token.Value == "{" then
		return self:parseBlock()
	elseif token.Value == "print" or token.Value == "printf" then
		self:advance()
		local args = {}
		while true do
			local nextToken = self:peek()
			if not nextToken or nextToken.Kind == "eof" or nextToken.Value == ";" or nextToken.Value == "}" then break end
			table.insert(args, self:parseExpression(1))
			if not self:matchValue(",") then break end
		end
		self:matchValue(";")
		return { Kind = token.Value, Args = args }
	elseif token.Value == "if" then
		self:advance()
		self:expect("(")
		local condition = self:parseExpression(1)
		self:expect(")")
		local yes = self:parseStatement()
		local no = nil
		if self:matchValue("else") then
			no = self:parseStatement()
		end
		return { Kind = "if", Cond = condition, Yes = yes, No = no }
	elseif token.Value == "while" then
		self:advance()
		self:expect("(")
		local condition = self:parseExpression(1)
		self:expect(")")
		return { Kind = "while", Cond = condition, Body = self:parseStatement() }
	elseif token.Value == "do" then
		self:advance()
		local body = self:parseStatement()
		self:expect("while")
		self:expect("(")
		local condition = self:parseExpression(1)
		self:expect(")")
		return { Kind = "do", Cond = condition, Body = body }
	elseif token.Value == "for" then
		self:advance()
		self:expect("(")
		local init = nil
		if not self:matchValue(";") then
			init = self:parseExpression(1)
			self:expect(";")
		end
		local condition = nil
		if not self:matchValue(";") then
			condition = self:parseExpression(1)
			self:expect(";")
		end
		local step = nil
		if self:peek() and self:peek().Value ~= ")" then
			step = self:parseExpression(1)
		end
		self:expect(")")
		return { Kind = "for", Init = init, Cond = condition, Step = step, Body = self:parseStatement() }
	elseif token.Value == "break" or token.Value == "continue" or token.Value == "next" then
		self:advance()
		self:matchValue(";")
		return { Kind = token.Value }
	elseif token.Value == "exit" then
		self:advance()
		local code = nil
		if self:peek() and self:peek().Value ~= ";" and self:peek().Value ~= "}" then
			code = self:parseExpression(1)
		end
		self:matchValue(";")
		return { Kind = "exit", Code = code }
	end

	local expression = self:parseExpression(1)
	self:matchValue(";")
	return { Kind = "expr", Expr = expression }
end

function P:parseProgram()
	local rules = {}
	while true do
		local token = self:peek()
		if not token or token.Kind == "eof" then break end
		if token.Value == ";" then
			self:advance()
			continue
		end

		local rule = { Kind = "rule" }

		if token.Kind == "id" and (token.Value == "BEGIN" or token.Value == "END") then
			rule.Special = token.Value
			self:advance()
			rule.Action = self:parseBlock()
		elseif token.Value == "{" then
			rule.Pattern = nil
			rule.Action = self:parseBlock()
		else
			rule.Pattern = self:parseExpression(1)
			if self:matchValue(",") then
				rule.Pattern2 = self:parseExpression(1)
			end
			if self:peek() and self:peek().Value == "{" then
				rule.Action = self:parseBlock()
			end
		end

		table.insert(rules, rule)
	end
	return rules
end

--// Runtime //--

local function truthy(value): boolean
	if type(value) == "number" then return value ~= 0 end
	if type(value) == "table" and value.__regex then return false end
	return value ~= nil and tostring(value) ~= ""
end

local function toNumber(value): number
	if type(value) == "number" then return value end
	local number = tonumber(tostring(value))
	return number or 0
end

local function toText(value): string
	if type(value) == "table" and value.__regex then return value.__regex end
	return tostring(value)
end

local function isNumeric(value): boolean
	if type(value) == "number" then return true end
	return tonumber(tostring(value)) ~= nil
end

local function printfFormat(format: string, args: { any }): string
	local out = {}
	local index = 1
	local i = 1

	while i <= #format do
		local c = string.sub(format, i, i)
		if c == "\\" then
			local n = string.sub(format, i + 1, i + 1)
			local map = { n = "\n", t = "\t", r = "\r", ["\\"] = "\\" }
			table.insert(out, map[n] or n)
			i += 2
		elseif c == "%" and string.sub(format, i + 1, i + 1) ~= "%" then
			local j = i + 1
			local spec = "%"
			while j <= #format and string.match(string.sub(format, j, j), "[%+%-0-9%.]") do
				spec ..= string.sub(format, j, j)
				j += 1
			end
			local conversion = string.sub(format, j, j)
			spec ..= conversion
			j += 1
			local value = args[index]
			index += 1

			if conversion == "s" then
				table.insert(out, toText(value))
			elseif conversion == "d" or conversion == "i" then
				table.insert(out, string.format(spec, math.floor(toNumber(value))))
			elseif conversion == "f" or conversion == "e" or conversion == "g" then
				table.insert(out, string.format(spec, toNumber(value)))
			elseif conversion == "c" then
				local text = toText(value)
				table.insert(out, string.sub(text, 1, 1))
			elseif conversion == "x" or conversion == "X" or conversion == "o" then
				table.insert(out, string.format(spec, math.floor(toNumber(value))))
			else
				table.insert(out, "%" .. conversion)
			end
			i = j
		elseif c == "%" then
			table.insert(out, "%")
			i += 2
		else
			table.insert(out, c)
			i += 1
		end
	end

	return table.concat(out)
end

local Interpreter = {}
Interpreter.__index = Interpreter

function Interpreter.new(program, options)
	local self = setmetatable({}, Interpreter)
	self.Program = program
	self.Output = {}
	self.Vars = {}
	self.Arrays = {}
	self.Fields = {}
	self.Record = ""
	self.NR = 0
	self.FNR = 0
	self.FS = options.FS or " "
	self.OFS = " "
	self.ORS = "\n"
	self.RS = "\n"
	self.RegexCache = {}
	self.Exit = false
	self.ExitCode = 0
	self.Steps = 0
	self.MaxSteps = 200000

	for name, value in options.Vars or {} do
		self.Vars[name] = value
	end

	self:SetRecord("")
	return self
end

function Interpreter:Step()
	self.Steps += 1
	if self.Steps > self.MaxSteps then
		error("awk: execution limit exceeded", 0)
	end
end

function Interpreter:Regex(pattern: string)
	local cached = self.RegexCache[pattern]
	if not cached then
		cached = Regex.compile(pattern)
		self.RegexCache[pattern] = cached
	end
	return cached
end

function Interpreter:SplitRecord()
	local record = self.Record
	local fields = {}

	if self.FS == " " then
		for field in string.gmatch(record, "%S+") do table.insert(fields, field) end
	elseif #self.FS == 1 then
		fields = string.split(record, self.FS)
	else
		local matcher = self:Regex(self.FS)
		local start = 1
		while start <= #record do
			local s, e = matcher:Find(record, start)
			if not s then
				table.insert(fields, string.sub(record, start))
				break
			end
			table.insert(fields, string.sub(record, start, s - 1))
			start = if e >= s then e + 1 else s + 1
		end
	end

	self.Fields = fields
	self.Vars.NF = #fields
end

function Interpreter:SetRecord(record: string)
	self.Record = record
	self:SplitRecord()
end

function Interpreter:RebuildRecord()
	self.Record = table.concat(self.Fields, self.OFS)
end

function Interpreter:GetField(index: number): string
	index = math.floor(index)
	if index == 0 then return self.Record end
	return self.Fields[index] or ""
end

function Interpreter:SetField(index: number, value: any)
	index = math.floor(index)
	if index == 0 then
		self:SetRecord(toText(value))
		return
	end
	if index > #self.Fields then
		for i = #self.Fields + 1, index do
			self.Fields[i] = ""
		end
	end
	self.Fields[index] = toText(value)
	self.Vars.NF = #self.Fields
	self:RebuildRecord()
end

function Interpreter:GetVar(name: string): any
	if name == "NF" then return #self.Fields end
	if name == "NR" then return self.NR end
	if name == "FNR" then return self.FNR end
	if name == "FS" then return self.FS end
	if name == "OFS" then return self.OFS end
	if name == "ORS" then return self.ORS end
	if name == "RS" then return self.RS end
	if name == "NR" then return self.NR end
	if name == "RSTART" then return self.Vars.RSTART or 0 end
	if name == "RLENGTH" then return self.Vars.RLENGTH or 0 end
	local value = self.Vars[name]
	if value == nil then return "" end
	return value
end

function Interpreter:SetVar(name: string, value: any)
	if name == "FS" then
		self.FS = toText(value)
		self:SplitRecord()
	elseif name == "OFS" then
		self.OFS = toText(value)
	elseif name == "ORS" then
		self.ORS = toText(value)
	elseif name == "RS" then
		self.RS = toText(value)
	elseif name == "NF" then
		local count = math.floor(toNumber(value))
		for i = #self.Fields + 1, count do self.Fields[i] = "" end
		for i = #self.Fields, count + 1, -1 do self.Fields[i] = nil end
		self.Vars.NF = count
		self:RebuildRecord()
	elseif name ~= "NR" and name ~= "FNR" then
		self.Vars[name] = value
	end
end

local function lvalue(node)
	if node.Kind == "var" then
		return function(state, value) state:SetVar(node.Name, value) end
	elseif node.Kind == "field" then
		return function(state, value) state:SetField(toNumber(state:Eval(node.Index)), value) end
	elseif node.Kind == "array" then
		return function(state, value)
			local array = state.Arrays[node.Name] or {}
			state.Arrays[node.Name] = array
			array[toText(state:Eval(node.Index))] = value
		end
	end
	return nil
end

function Interpreter:PatternValue(node)
	local value = self:Eval(node)
	if type(value) == "table" and value.__regex then
		return self:Regex(value.__regex):Test(self.Record)
	end
	return truthy(value)
end

function Interpreter:Eval(node): any
	if not node then return "" end
	self:Step()

	local kind = node.Kind

	if kind == "num" or kind == "str" then
		return node.Value
	elseif kind == "regex" then
		return { __regex = node.Pattern }
	elseif kind == "var" then
		return self:GetVar(node.Name)
	elseif kind == "array" then
		local array = self.Arrays[node.Name] or {}
		return array[toText(self:Eval(node.Index))] or ""
	elseif kind == "field" then
		return self:GetField(toNumber(self:Eval(node.Index)))
	elseif kind == "concat" then
		return toText(self:Eval(node.Left)) .. toText(self:Eval(node.Right))
	elseif kind == "unary" then
		local value = self:Eval(node.Value)
		if node.Op == "!" then return if truthy(value) then 0 else 1 end
		if node.Op == "-" then return -toNumber(value) end
		if node.Op == "+" then return toNumber(value) end
		return value
	elseif kind == "ternary" then
		return if truthy(self:Eval(node.Cond)) then self:Eval(node.Yes) else self:Eval(node.No)
	elseif kind == "incdec" then
		local setter = lvalue(node.Target)
		if not setter then error("awk: ++/-- needs an lvalue", 0) end
		local current = node.Target.Kind == "var" and self:GetVar(node.Target.Name)
			or node.Target.Kind == "field" and self:GetField(toNumber(self:Eval(node.Target.Index)))
			or 0
		local old = toNumber(current)
		local new = if node.Op == "++" then old + 1 else old - 1
		setter(self, new)
		return if node.Prefix then new else old
	elseif kind == "assign" then
		local setter = lvalue(node.Target)
		if not setter then error("awk: assignment needs an lvalue", 0) end
		local value = self:Eval(node.Value)
		if node.Op ~= "=" then
			local current = self:Eval(node.Target)
			local op = string.sub(node.Op, 1, 1)
			if op == "+" then value = toNumber(current) + toNumber(value)
			elseif op == "-" then value = toNumber(current) - toNumber(value)
			elseif op == "*" then value = toNumber(current) * toNumber(value)
			elseif op == "/" then value = toNumber(current) / toNumber(value)
			elseif op == "%" then value = toNumber(current) % toNumber(value)
			elseif op == "^" then value = toNumber(current) ^ toNumber(value) end
		end
		setter(self, value)
		return value
	elseif kind == "binary" then
		local op = node.Op
		if op == "&&" then
			if not truthy(self:Eval(node.Left)) then return 0 end
			return if truthy(self:Eval(node.Right)) then 1 else 0
		elseif op == "||" then
			if truthy(self:Eval(node.Left)) then return 1 end
			return if truthy(self:Eval(node.Right)) then 1 else 0
		end

		local left = self:Eval(node.Left)
		local right = self:Eval(node.Right)

		if op == "~" or op == "!~" then
			local pattern = if type(right) == "table" and right.__regex then right.__regex else toText(right)
			local matched = self:Regex(pattern):Test(toText(left))
			if op == "!~" then matched = not matched end
			return if matched then 1 else 0
		elseif op == "==" or op == "!=" or op == "<" or op == "<=" or op == ">" or op == ">=" then
			local result
			if isNumeric(left) and isNumeric(right) then
				local a, b = toNumber(left), toNumber(right)
				if op == "==" then result = a == b
				elseif op == "!=" then result = a ~= b
				elseif op == "<" then result = a < b
				elseif op == "<=" then result = a <= b
				elseif op == ">" then result = a > b
				else result = a >= b end
			else
				local a, b = toText(left), toText(right)
				if op == "==" then result = a == b
				elseif op == "!=" then result = a ~= b
				elseif op == "<" then result = a < b
				elseif op == "<=" then result = a <= b
				elseif op == ">" then result = a > b
				else result = a >= b end
			end
			return if result then 1 else 0
		elseif op == "+" then return toNumber(left) + toNumber(right)
		elseif op == "-" then return toNumber(left) - toNumber(right)
		elseif op == "*" then return toNumber(left) * toNumber(right)
		elseif op == "/" then return toNumber(left) / toNumber(right)
		elseif op == "%" then return toNumber(left) % toNumber(right)
		elseif op == "^" then return toNumber(left) ^ toNumber(right)
		end
	elseif kind == "call" then
		return self:Call(node.Name, node.Args)
	end

	return ""
end

function Interpreter:Call(name: string, args: { any }): any
	local values = {}
	for _, arg in args do
		table.insert(values, self:Eval(arg))
	end

	if name == "length" then
		if #values == 0 then return #self.Record end
		return #toText(values[1])
	elseif name == "substr" then
		local text = toText(values[1])
		local start = math.max(1, math.floor(toNumber(values[2])))
		if values[3] ~= nil then
			return string.sub(text, start, start + math.floor(toNumber(values[3])) - 1)
		end
		return string.sub(text, start)
	elseif name == "index" then
		local s, e = string.find(toText(values[1]), toText(values[2]), 1, true)
		return s or 0
	elseif name == "toupper" then
		return string.upper(toText(values[1]))
	elseif name == "tolower" then
		return string.lower(toText(values[1]))
	elseif name == "int" then
		return math.floor(toNumber(values[1]))
	elseif name == "sqrt" then
		return math.sqrt(toNumber(values[1]))
	elseif name == "exp" then
		return math.exp(toNumber(values[1]))
	elseif name == "log" then
		return math.log(toNumber(values[1]))
	elseif name == "sin" then
		return math.sin(toNumber(values[1]))
	elseif name == "cos" then
		return math.cos(toNumber(values[1]))
	elseif name == "atan2" then
		return math.atan2(toNumber(values[1]), toNumber(values[2]))
	elseif name == "rand" then
		return math.random()
	elseif name == "srand" then
		return os.time()
	elseif name == "sprintf" then
		local format = toText(values[1])
		local rest = {}
		for i = 2, #values do table.insert(rest, values[i]) end
		return printfFormat(format, rest)
	elseif name == "match" then
		local text = toText(values[1])
		local pattern = if type(values[2]) == "table" then values[2].__regex else toText(values[2])
		local s, e = self:Regex(pattern):Find(text)
		if s then
			self.Vars.RSTART = s
			self.Vars.RLENGTH = e - s + 1
			return s
		end
		self.Vars.RSTART = 0
		self.Vars.RLENGTH = -1
		return 0
	elseif name == "split" then
		local text = toText(values[1])
		local target = args[2]
		if target and target.Kind == "var" then
			local separator = if values[3] ~= nil then toText(values[3]) else self.FS
			local pieces = if separator == " " then (function()
				local list = {}
				for piece in string.gmatch(text, "%S+") do table.insert(list, piece) end
				return list
			end)() else string.split(text, separator)
			local array = {}
			for i, piece in pieces do array[tostring(i)] = piece end
			self.Arrays[target.Name] = array
			return #pieces
		end
		return 0
	elseif name == "sub" or name == "gsub" then
		local pattern = if type(values[1]) == "table" then values[1].__regex else toText(values[1])
		local replacement = toText(values[2])
		local target = args[3] or { Kind = "field", Index = { Kind = "num", Value = 0 } }
		local setter = lvalue(target)
		if not setter then return 0 end
		local current = self:Eval(target)
		local matcher = self:Regex(pattern)
		local out = {}
		local position = 1
		local count = 0

		while position <= #toText(current) do
			local s, e = matcher:Find(toText(current), position)
			if not s then break end
			table.insert(out, string.sub(toText(current), position, s - 1))
			table.insert(out, string.gsub(replacement, "&", string.sub(toText(current), s, e)))
			position = e + 1
			count += 1
			if name == "sub" then break end
		end

		if count > 0 then
			table.insert(out, string.sub(toText(current), position))
			setter(self, table.concat(out))
		end
		return count
	end

	error(`awk: function '{name}' is not implemented`, 0)
end

local BREAK = { __control = "break" }
local CONTINUE = { __control = "continue" }
local NEXT = { __control = "next" }
local EXIT = { __control = "exit" }

function Interpreter:Exec(node)
	if not node then return nil end
	self:Step()

	local kind = node.Kind

	if kind == "block" then
		for _, statement in node.Body do
			local control = self:Exec(statement)
			if control then return control end
		end
		return nil
	elseif kind == "expr" then
		self:Eval(node.Expr)
		return nil
	elseif kind == "print" then
		local parts = {}
		if #node.Args == 0 then
			table.insert(parts, self.Record)
		else
			for _, arg in node.Args do
				table.insert(parts, toText(self:Eval(arg)))
			end
		end
		table.insert(self.Output, table.concat(parts, self.OFS) .. self.ORS)
		return nil
	elseif kind == "printf" then
		if #node.Args == 0 then return nil end
		local format = toText(self:Eval(node.Args[1]))
		local values = {}
		for i = 2, #node.Args do table.insert(values, self:Eval(node.Args[i])) end
		table.insert(self.Output, printfFormat(format, values))
		return nil
	elseif kind == "if" then
		if truthy(self:Eval(node.Cond)) then
			return self:Exec(node.Yes)
		elseif node.No then
			return self:Exec(node.No)
		end
		return nil
	elseif kind == "while" then
		while truthy(self:Eval(node.Cond)) do
			local control = self:Exec(node.Body)
			if control == BREAK then break end
			if control and control ~= CONTINUE then return control end
			self:Step()
		end
		return nil
	elseif kind == "do" then
		repeat
			local control = self:Exec(node.Body)
			if control == BREAK then break end
			if control and control ~= CONTINUE then return control end
			self:Step()
		until not truthy(self:Eval(node.Cond))
		return nil
	elseif kind == "for" then
		if node.Init then self:Eval(node.Init) end
		while node.Cond == nil or truthy(self:Eval(node.Cond)) do
			local control = self:Exec(node.Body)
			if control == BREAK then break end
			if control and control ~= CONTINUE then return control end
			if node.Step then self:Eval(node.Step) end
			self:Step()
		end
		return nil
	elseif kind == "break" then
		return BREAK
	elseif kind == "continue" then
		return CONTINUE
	elseif kind == "next" then
		return NEXT
	elseif kind == "exit" then
		self.Exit = true
		if node.Code then self.ExitCode = math.floor(toNumber(self:Eval(node.Code))) end
		return EXIT
	end

	return nil
end

function Interpreter:Run(lines)
	local beginRules = {}
	local endRules = {}
	local rules = {}

	for _, rule in self.Program do
		if rule.Special == "BEGIN" then table.insert(beginRules, rule)
		elseif rule.Special == "END" then table.insert(endRules, rule)
		else table.insert(rules, rule) end
	end

	for _, rule in beginRules do
		local control = self:Exec(rule.Action)
		if control == EXIT then break end
	end

	if not self.Exit then
		for _, line in lines do
			if self.Exit then break end
			self.NR += 1
			self.FNR += 1
			self:SetRecord(line)

			for _, rule in rules do
				local matched = true
				if rule.Pattern then
					matched = self:PatternValue(rule.Pattern)
					if matched and rule.Pattern2 then
						if not rule.RangeActive then
							rule.RangeActive = true
						end
					end
				end

				if rule.Pattern2 and rule.RangeActive then
					matched = true
				end

				if matched then
					local control
					if rule.Action then
						control = self:Exec(rule.Action)
					else
						table.insert(self.Output, self.Record .. self.ORS)
					end

					if rule.Pattern2 and rule.RangeActive and self:PatternValue(rule.Pattern2) then
						rule.RangeActive = false
					end

					if control == NEXT then break end
					if control == EXIT then break end
				end
			end
		end
	end

	for _, rule in endRules do
		self:Exec(rule.Action)
	end

	return table.concat(self.Output), self.ExitCode
end

return {
	Name = "awk",
	Permission = "Any",
	Description = "Pattern scanning and processing language (practical subset)",
	Args = {},
	Run = function(context)
		local options, operands, err = Getopt.parse(context.Args, "F:v:f:", {
			field_separator = "F",
			assign = "v",
			file = "f",
		})

		if err then
			context:Error(`awk: {err}`, 2)
			return ""
		end

		if options.f then
			context:Error("awk: -f: there is no filesystem", 2)
			return ""
		end

		local program = table.remove(operands, 1)
		if not program then
			context:Error("awk: no program given", 2)
			return ""
		end

		if #operands > 0 then
			context:Error(`awk: {operands[1]}: No such file or directory`, 2)
			return ""
		end

		local vars = {}
		if options.v then
			local name, value = string.match(options.v, "^([^=]+)=(.*)$")
			if name then vars[name] = value end
		end

		local tokens, tokenError = tokenize(program)
		if not tokens then
			context:Error(`awk: {tokenError}`, 2)
			return ""
		end

		local parser = P.new(tokens)
		local ok, rules = pcall(function()
			return parser:parseProgram()
		end)

		if not ok then
			context:Error(tostring(rules), 2)
			return ""
		end

		local interpreter = Interpreter.new(rules, {
			FS = options.F or " ",
			Vars = vars,
		})

		local success, output, code = pcall(function()
			return interpreter:Run(Text.lines(context:GetInput()))
		end)

		if not success then
			context:Error(tostring(output), 1)
			return ""
		end

		if code ~= 0 then context:SetCode(code) end
		return output
	end,
}
