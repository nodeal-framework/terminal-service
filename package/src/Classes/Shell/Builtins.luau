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
	Shell builtins. They receive the live Shell instance, so they can change variables,
	aliases, functions and positional parameters, and they can invoke other commands
	(`eval`, `xargs`, `command`, `env`).

	Every Run returns (code, stdout, stderr).
]=]

local Glob = require(script.Parent.Parent.Glob)
local Getopt = require(script.Parent.Parent.Getopt)
local Regex = require(script.Parent.Parent.Regex)
local Text = require(script.Parent.Parent.Text)

local Builtins = {}

--[=[
	Builds a successful builtin result.

	@param text The standard output text.
	@return The exit status, standard output and standard error.
]=]
local function ok(text: string?): (number, string, string)
	return 0, text or "", ""
end

--[=[
	Builds a failed builtin result with an exit code.

	@param message The error message.
	@param code The exit status.
	@return The exit status, standard output and standard error.
]=]
local function fail(message: string, code: number?): (number, string, string)
	return code or 1, "", message
end

--[=[
	Raises a shell control signal such as `break` or `return`.

	@param kind The control signal name.
	@param value The signal payload.
]=]
local function signal(kind: string, value: number?)
	error({ __shellControl = true, Kind = kind, Value = value or 0 }, 0)
end

--[=[
	Quotes a value for safe reuse in shell input.

	@param value The value to quote.
	@return The resulting text.
]=]
local function shellQuote(value: string): string
	return "'" .. string.gsub(value, "'", "'\\''") .. "'"
end

--[=[
	Checks whether a name is a valid shell identifier.

	@param name The name to look up.
	@return True when the condition holds.
]=]
local function isIdentifier(name: string): boolean
	return string.match(name, "^[%a_][%w_]*$") ~= nil
end

--// echo / printf //--

--[=[
	Expands backslash escapes in `echo -e` text.

	@param text The text to inspect.
	@return The resulting text.
]=]
local function interpretEscapes(text: string): string
	local out = {}
	local i = 1
	local len = #text

	while i <= len do
		local c = string.sub(text, i, i)
		if c ~= "\\" then
			table.insert(out, c)
			i += 1
		else
			local n = string.sub(text, i + 1, i + 1)
			local map = {
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
				["0"] = "\0",
			}
			if map[n] then
				table.insert(out, map[n])
				i += 2
			elseif n == "c" then
				break
			elseif n == "x" then
				local hex = string.match(string.sub(text, i + 2), "^%x%x?")
				if hex then
					table.insert(out, string.char(tonumber(hex, 16) % 256))
					i += 2 + #hex
				else
					table.insert(out, "\\x")
					i += 2
				end
			elseif n == "u" or n == "U" then
				local count = if n == "u" then 4 else 8
				local hex = string.match(string.sub(text, i + 2), "^%x+")
				if hex then
					hex = string.sub(hex, 1, count)
					local success, char = pcall(utf8.char, tonumber(hex, 16))
					table.insert(out, if success then char else "")
					i += 2 + #hex
				else
					table.insert(out, n)
					i += 2
				end
			elseif string.match(n, "%d") then
				local oct = string.match(string.sub(text, i + 1), "^[0-7][0-7]?[0-7]?")
				if oct then
					table.insert(out, string.char(tonumber(oct, 8) % 256))
					i += 1 + #oct
				else
					table.insert(out, n)
					i += 2
				end
			else
				table.insert(out, "\\")
				table.insert(out, n)
				i += 2
			end
		end
	end

	return table.concat(out)
end

--[=[
	`echo`: prints its arguments, optionally interpreting escapes.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinEcho(shell, arguments, stdin)
	local newline = true
	local escapes = false
	local i = 1

	while i <= #arguments do
		local argument = arguments[i]
		if argument == "-n" then
			newline = false
		elseif argument == "-e" then
			escapes = true
		elseif argument == "-E" then
			escapes = false
		elseif argument == "--" then
			i += 1
			break
		elseif string.match(argument, "^%-[neE]+$") then
			for j = 2, #argument do
				local c = string.sub(argument, j, j)
				if c == "n" then
					newline = false
				elseif c == "e" then
					escapes = true
				elseif c == "E" then
					escapes = false
				end
			end
		else
			break
		end
		i += 1
	end

	local parts = {}
	for j = i, #arguments do
		table.insert(parts, arguments[j])
	end

	local text = table.concat(parts, " ")
	if escapes then
		text = interpretEscapes(text)
	end

	if newline then
		text ..= "\n"
	end

	return ok(text)
end

--[=[
	Formats an integer in the given base.

	@param value The value to convert.
	@param base The numeric base.
	@param upper Whether to use uppercase digits.
	@return The resulting text.
]=]
local function toBase(value: number, base: number, upper: boolean): string
	local digits = if upper then "0123456789ABCDEF" else "0123456789abcdef"
	local n = math.floor(math.abs(value))
	if n == 0 then
		return "0"
	end
	local out = {}
	while n > 0 do
		local d = n % base
		table.insert(out, 1, string.sub(digits, d + 1, d + 1))
		n = math.floor(n / base)
	end
	return table.concat(out)
end

--[=[
	Pads a formatted number to the requested width.

	@param text The text to inspect.
	@param width The target width.
	@param flags The formatting flags.
	@param negative Whether the number is negative.
	@return The resulting text.
]=]
local function padNumber(text: string, width: number, flags: string, negative: boolean): string
	if width <= #text then
		if negative then
			return "-" .. text
		end
		return text
	end

	if string.find(flags, "0", 1, true) and not string.find(flags, "-", 1, true) then
		local sign = if negative then "-" else ""
		return sign .. string.rep("0", width - #text - #sign) .. text
	end

	if negative then
		text = "-" .. text
	end

	local signed = text
	if string.find(flags, "-", 1, true) then
		return signed .. string.rep(" ", math.max(0, width - #signed))
	end
	return string.rep(" ", math.max(0, width - #signed)) .. signed
end

--[=[
	`printf`: formats and prints its arguments.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinPrintf(shell, arguments, stdin)
	if #arguments == 0 then
		return fail("printf: usage: printf FORMAT [ARGUMENT]...", 2)
	end

	local varName = nil
	local start = 1
	while start <= #arguments do
		if arguments[start] == "-v" then
			start += 1
			varName = arguments[start]
			start += 1
		elseif arguments[start] == "--" then
			start += 1
			break
		else
			break
		end
	end

	local format = arguments[start]
	if format == nil then
		return fail("printf: usage: printf FORMAT [ARGUMENT]...", 2)
	end

	local values = {}
	for i = start + 1, #arguments do
		table.insert(values, arguments[i])
	end

	--[=[
		Formats one `printf` conversion from the argument list.

		@param fmt The conversion specification.
		@param valueIndex The printf argument cursor.
		@return The resulting text.
	]=]
	local function formatOne(fmt: string, valueIndex: any): string
		local out = {}
		local i = 1
		local len = #fmt
		local argIndex = valueIndex.n

		while i <= len do
			local c = string.sub(fmt, i, i)
			if c ~= "%" then
				if c == "\\" then
					local nextChar = string.sub(fmt, i + 1, i + 1)
					local escapes = {
						["n"] = "\n",
						["t"] = "\t",
						["r"] = "\r",
						["a"] = "\a",
						["b"] = "\b",
						["f"] = "\f",
						["v"] = "\v",
						["\\"] = "\\",
						["0"] = "\0",
					}
					if escapes[nextChar] then
						table.insert(out, escapes[nextChar])
						i += 2
					elseif nextChar == "x" then
						local hex = string.match(string.sub(fmt, i + 2), "^%x%x?")
						if hex then
							table.insert(out, string.char(tonumber(hex, 16) % 256))
							i += 2 + #hex
						else
							table.insert(out, "\\x")
							i += 2
						end
					else
						table.insert(out, "\\")
						i += 1
					end
				else
					table.insert(out, c)
					i += 1
				end
			else
				if string.sub(fmt, i + 1, i + 1) == "%" then
					table.insert(out, "%")
					i += 2
					continue
				end

				local j = i + 1
				local flags = ""
				while string.find("-+ 0#", string.sub(fmt, j, j), 1, true) do
					flags ..= string.sub(fmt, j, j)
					j += 1
				end

				local width = 0
				if string.sub(fmt, j, j) == "*" then
					argIndex += 1
					width = tonumber(values[argIndex]) or 0
					j += 1
				else
					local digits = string.match(string.sub(fmt, j), "^%d+")
					if digits then
						width = tonumber(digits) or 0
						j += #digits
					end
				end

				local precision = nil
				if string.sub(fmt, j, j) == "." then
					j += 1
					if string.sub(fmt, j, j) == "*" then
						argIndex += 1
						precision = tonumber(values[argIndex]) or 0
						j += 1
					else
						local digits = string.match(string.sub(fmt, j), "^%d+")
						if digits then
							precision = tonumber(digits)
							j += #digits
						else
							precision = 0
						end
					end
				end

				local conversion = string.sub(fmt, j, j)
				j += 1
				argIndex += 1
				local value = values[argIndex]

				if conversion == "s" or conversion == "b" or conversion == "q" then
					local text = tostring(value or "")
					if conversion == "b" then
						text = interpretEscapes(text)
					elseif conversion == "q" then
						text = shellQuote(text)
					end
					if precision then
						text = string.sub(text, 1, precision)
					end
					if width > #text then
						text = if string.find(flags, "-", 1, true)
							then text .. string.rep(" ", width - #text)
							else string.rep(" ", width - #text) .. text
					end
					table.insert(out, text)
				elseif conversion == "c" then
					local text = string.sub(tostring(value or ""), 1, 1)
					if width > 1 then
						text = if string.find(flags, "-", 1, true)
							then text .. string.rep(" ", width - 1)
							else string.rep(" ", width - 1) .. text
					end
					table.insert(out, text)
				elseif
					conversion == "d"
					or conversion == "i"
					or conversion == "u"
					or conversion == "o"
					or conversion == "x"
					or conversion == "X"
				then
					local number = tonumber(value) or 0
					local negative = number < 0 and (conversion == "d" or conversion == "i")
					local text = nil
					if conversion == "d" or conversion == "i" then
						text = tostring(math.floor(math.abs(number)))
					elseif conversion == "u" then
						text = tostring(math.floor(math.max(0, number)))
					elseif conversion == "o" then
						text = toBase(number, 8, false)
					elseif conversion == "x" then
						text = toBase(number, 16, false)
					else
						text = toBase(number, 16, true)
					end
					if precision and #text < precision then
						text = string.rep("0", precision - #text) .. text
					end
					if string.find(flags, "#", 1, true) then
						if conversion == "x" then
							text = "0x" .. text
						elseif conversion == "X" then
							text = "0X" .. text
						elseif conversion == "o" then
							text = "0" .. text
						end
					end
					table.insert(out, padNumber(text, width, flags, negative))
				elseif
					conversion == "f"
					or conversion == "F"
					or conversion == "e"
					or conversion == "E"
					or conversion == "g"
					or conversion == "G"
				then
					local number = tonumber(value) or 0
					local spec = "%"
						.. flags
						.. (if width > 0 then tostring(width) else "")
						.. (if precision then "." .. precision else "")
						.. conversion
					local success, text = pcall(string.format, spec, number)
					table.insert(out, if success then text else tostring(number))
				elseif conversion == "n" then
				else
					table.insert(out, "%" .. conversion)
				end

				i = j
			end
		end

		valueIndex.n = argIndex
		return table.concat(out)
	end

	local result = {}
	local valueIndex = { n = 0 }
	local passes = 0

	repeat
		local before = valueIndex.n
		table.insert(result, formatOne(format, valueIndex))
		passes += 1

		if #values == 0 then
			break
		end
		if valueIndex.n == before then
			break
		end
	until valueIndex.n >= #values or passes > 64

	local text = table.concat(result)
	if varName then
		shell:SetVar(varName, text)
		return 0, "", ""
	end
	return ok(text)
end

--// test / [ //--

--[=[
	Evaluates a unary `test` operator.

	@param op The operator to apply.
	@param value The value to convert.
	@param shell The shell instance.
	@return True when the condition holds.
]=]
local function testUnary(op: string, value: string, shell): boolean?
	if op == "-n" then
		return value ~= ""
	end
	if op == "-z" then
		return value == ""
	end
	if op == "-v" then
		return shell:GetVar(value) ~= nil
	end
	if op == "-o" then
		local name = string.match(value, "^%+?o$")
		if name then
			return true
		end
		return shell.Options[value] == true
	end
	if op == "-t" then
		return false
	end
	if
		op == "-e"
		or op == "-a"
		or op == "-f"
		or op == "-d"
		or op == "-r"
		or op == "-w"
		or op == "-x"
		or op == "-s"
		or op == "-L"
		or op == "-h"
		or op == "-p"
		or op == "-S"
		or op == "-b"
		or op == "-c"
		or op == "-g"
		or op == "-u"
		or op == "-k"
		or op == "-O"
		or op == "-G"
		or op == "-N"
	then
		return false
	end
	return nil
end

--[=[
	Evaluates a binary `test` operator.

	@param left The left operand.
	@param op The operator to apply.
	@param right The right operand.
	@return True when the condition holds.
]=]
local function testBinary(left: string, op: string, right: string): boolean?
	if op == "=" or op == "==" then
		return left == right
	end
	if op == "!=" then
		return left ~= right
	end
	if op == "<" then
		return left < right
	end
	if op == ">" then
		return left > right
	end

	local a = tonumber(left)
	local b = tonumber(right)
	if op == "-eq" then
		return a ~= nil and b ~= nil and a == b
	end
	if op == "-ne" then
		return a ~= nil and b ~= nil and a ~= b
	end
	if op == "-lt" then
		return a ~= nil and b ~= nil and a < b
	end
	if op == "-le" then
		return a ~= nil and b ~= nil and a <= b
	end
	if op == "-gt" then
		return a ~= nil and b ~= nil and a > b
	end
	if op == "-ge" then
		return a ~= nil and b ~= nil and a >= b
	end
	return nil
end

--[=[
	Parses and evaluates a `test` expression.

	@param arguments The command arguments.
	@param shell The shell instance.
	@param patternMode Whether the operand is a pattern.
	@return The exit status, standard output and standard error.
]=]
local function evalTest(arguments, shell, patternMode: boolean): (boolean, string?)
	local position = 1

	--[=[
		Returns the next `test` token without consuming it.

		@return The next token, or nil.
	]=]
	local function peek()
		return arguments[position]
	end
	--[=[
		Consumes and returns the next `test` token.

		@return The consumed token.
	]=]
	local function advance()
		local v = arguments[position]
		position += 1
		return v
	end

	local parseOr, parseAnd, parseNot, parsePrimary

	--[=[
		Parses a primary `test` expression.

		@return The parsed test node.
	]=]
	function parsePrimary()
		local token = peek()
		if token == nil then
			return nil, "argument expected"
		end

		if token == "(" then
			advance()
			local value, errorValue = parseOr()
			if value == nil then
				return nil, errorValue
			end
			if peek() ~= ")" then
				return nil, "')' expected"
			end
			advance()
			return value
		end

		local unary = testUnary(token, arguments[position + 1] or "", shell)
		if unary ~= nil then
			advance()
			advance()
			return unary
		end

		local left = advance()
		local op = peek()
		if op == nil or op == ")" or op == "-a" or op == "-o" then
			return left ~= ""
		end

		if patternMode and (op == "==" or op == "=") then
			advance()
			local right = advance()
			if right == nil then
				return nil, "argument expected"
			end
			return Glob.match(left, right)
		elseif patternMode and op == "!=" then
			advance()
			local right = advance()
			if right == nil then
				return nil, "argument expected"
			end
			return not Glob.match(left, right)
		elseif patternMode and op == "=~" then
			advance()
			local right = advance()
			if right == nil then
				return nil, "argument expected"
			end
			local ok, matcher = pcall(Regex.compile, right)
			if not ok then
				return nil, "invalid regular expression"
			end
			return matcher:Test(left)
		else
			local result = testBinary(left, op, peek() and arguments[position + 1] or "")
			if result ~= nil then
				advance()
				advance()
				return result
			end
		end

		return left ~= ""
	end

	--[=[
		Parses a negated `test` expression.

		@return The parsed test node.
	]=]
	function parseNot()
		if peek() == "!" then
			advance()
			local value, errorValue = parseNot()
			if value == nil then
				return nil, errorValue
			end
			return not value
		end
		return parsePrimary()
	end

	--[=[
		Parses `-a` conjunctions.

		@return The parsed test node.
	]=]
	function parseAnd()
		local value, errorValue = parseNot()
		if value == nil then
			return nil, errorValue
		end
		while peek() == "-a" do
			advance()
			local right, err2 = parseNot()
			if right == nil then
				return nil, err2
			end
			value = value and right
		end
		return value
	end

	--[=[
		Parses `-o` disjunctions.

		@return The parsed test node.
	]=]
	function parseOr()
		local value, errorValue = parseAnd()
		if value == nil then
			return nil, errorValue
		end
		while peek() == "-o" do
			advance()
			local right, err2 = parseAnd()
			if right == nil then
				return nil, err2
			end
			value = value or right
		end
		return value
	end

	local value, errorValue = parseOr()
	if value == nil then
		return false, errorValue
	end
	if position <= #arguments then
		return false, `too many arguments near '{arguments[position]}'`
	end
	return value
end

--[=[
	`test` and `[`: evaluates a conditional expression.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@param bracket Whether this is the `[` form.
	@param extended Whether extended test syntax is enabled.
	@return The exit status, standard output and standard error.
]=]
local function builtinTest(shell, arguments, stdin, bracket: boolean?, extended: boolean?)
	local list = arguments
	if bracket then
		if #list == 0 or list[#list] ~= "]" then
			return fail("[: missing `]'", 2)
		end
		list = table.clone(list)
		table.remove(list)
	elseif extended and #list > 0 and list[#list] == "]]" then
		list = table.clone(list)
		table.remove(list)
	end

	if extended then
		for i, value in list do
			if value == "&&" then
				list[i] = "-a"
			elseif value == "||" then
				list[i] = "-o"
			end
		end
	end

	if #list == 0 then
		return 1, "", ""
	end

	local result, errorValue = evalTest(list, shell, extended == true)
	if errorValue then
		return fail(`{(bracket and "[" or "test")}: {errorValue}`, 2)
	end
	if result then
		return 0, "", ""
	end
	return 1, "", ""
end

--// Variables //--

--[=[
	Formats one shell variable for `export` or `set` output.

	@param shell The shell instance.
	@param name The name to look up.
	@param exportedOnly Whether to skip unexported variables.
	@return The resulting text, or nil.
]=]
local function printVar(shell, name: string, exportedOnly: boolean?): string?
	if exportedOnly and not shell.Exported[name] then
		return nil
	end
	local value = shell:GetVar(name)
	if value == nil then
		return nil
	end
	return `{name}={shellQuote(value)}`
end

--[=[
	`export`: marks variables for the environment or prints them.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinExport(shell, arguments, stdin)
	local printMode = false
	local unexport = false
	local i = 1
	while i <= #arguments and string.sub(arguments[i], 1, 1) == "-" and arguments[i] ~= "-" do
		if arguments[i] == "-p" then
			printMode = true
		elseif arguments[i] == "-n" then
			unexport = true
		elseif arguments[i] == "--" then
			i += 1
			break
		else
			return fail(`export: {arguments[i]}: invalid option`, 2)
		end
		i += 1
	end

	if printMode or i > #arguments then
		local names = {}
		for name in shell.Exported do
			table.insert(names, name)
		end
		table.sort(names)
		local out = {}
		for _, name in names do
			table.insert(out, `declare -x {printVar(shell, name, true) or name}`)
		end
		return ok(table.concat(out, "\n"))
	end

	for j = i, #arguments do
		local name, value = string.match(arguments[j], "^([^=]+)=(.*)$")
		if name then
			if not isIdentifier(name) then
				return fail(`export: '{name}': not a valid identifier`, 1)
			end
			shell:SetVar(name, value, not unexport)
			if unexport then
				shell.Exported[name] = nil
			end
		else
			if not isIdentifier(arguments[j]) then
				return fail(`export: '{arguments[j]}': not a valid identifier`, 1)
			end
			if unexport then
				shell.Exported[arguments[j]] = nil
			else
				shell.Exported[arguments[j]] = true
			end
		end
	end

	return ok("")
end

--[=[
	`unset`: removes variables, functions or array elements.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinUnset(shell, arguments, stdin)
	local functions = false
	local i = 1
	while i <= #arguments do
		if arguments[i] == "-f" then
			functions = true
		elseif arguments[i] == "-v" then
			functions = false
		elseif arguments[i] == "--" then
			i += 1
			break
		elseif string.sub(arguments[i], 1, 1) == "-" then
			return fail(`unset: {arguments[i]}: invalid option`, 2)
		else
			break
		end
		i += 1
	end

	for j = i, #arguments do
		if functions then
			shell.Functions[arguments[j]] = nil
		else
			if shell.Readonly[arguments[j]] then
				return fail(`unset: {arguments[j]}: cannot unset: readonly variable`, 1)
			end
			shell:SetVar(arguments[j], nil)
			shell.Arrays[arguments[j]] = nil
			shell.Exported[arguments[j]] = nil
		end
	end
	return ok("")
end

local OPTION_NAMES = {
	pipefail = true,
	errexit = true,
	nounset = true,
	xtrace = true,
	noglob = true,
	noclobber = true,
	monitor = true,
	history = true,
	interactive = true,
	emacs = true,
	vi = true,
	allexport = true,
}

--[=[
	`set`: prints variables or changes shell options and positional parameters.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinSet(shell, arguments, stdin)
	if #arguments == 0 then
		local names = {}
		for name in shell.Vars do
			table.insert(names, name)
		end
		table.sort(names)
		local out = {}
		for _, name in names do
			table.insert(out, `{name}={shellQuote(shell.Vars[name])}`)
		end
		return ok(table.concat(out, "\n"))
	end

	local i = 1
	local positional = nil

	while i <= #arguments do
		local argument = arguments[i]
		if argument == "--" then
			positional = {}
			i += 1
			while i <= #arguments do
				table.insert(positional, arguments[i])
				i += 1
			end
			break
		elseif argument == "-o" or argument == "+o" then
			local enable = argument == "-o"
			i += 1
			local name = arguments[i]
			if name == nil then
				local out = {}
				local options = {}
				for opt in OPTION_NAMES do
					table.insert(options, opt)
				end
				table.sort(options)
				for _, opt in options do
					table.insert(out, `{opt}\t{if shell.Options[opt] then "on" else "off"}`)
				end
				return ok(table.concat(out, "\n"))
			end
			if not OPTION_NAMES[name] then
				return fail(`set: {name}: invalid option name`, 2)
			end
			shell.Options[name] = enable
			i += 1
		elseif string.match(argument, "^[%-+]%a+$") then
			local enable = string.sub(argument, 1, 1) == "-"
			for j = 2, #argument do
				local c = string.sub(argument, j, j)
				local map = {
					e = "errexit",
					u = "nounset",
					x = "xtrace",
					f = "noglob",
					C = "noclobber",
					m = "monitor",
					h = "history",
					a = "allexport",
				}
				if map[c] then
					shell.Options[map[c]] = enable
				elseif c == "o" then
				else
					return fail(`set: -{c}: invalid option`, 2)
				end
			end
			i += 1
		else
			positional = {}
			while i <= #arguments do
				table.insert(positional, arguments[i])
				i += 1
			end
			break
		end
	end

	if positional then
		shell.Positional = positional
	end
	return ok("")
end

--[=[
	`declare` and `typeset`: declare, export or print variables.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinDeclare(shell, arguments, stdin)
	local export = false
	local printMode = false
	local functionMode = false
	local readonlyMode = false
	local arrayMode = false
	local names = {}

	for _, argument in arguments do
		if argument == "-x" then
			export = true
		elseif argument == "-p" then
			printMode = true
		elseif argument == "-f" then
			functionMode = true
		elseif argument == "-r" then
			readonlyMode = true
		elseif argument == "-a" or argument == "-A" then
			arrayMode = true
		elseif string.sub(argument, 1, 1) ~= "-" then
			table.insert(names, argument)
		end
	end

	if functionMode then
		local list = if #names > 0
			then names
			else (function()
				local all = {}
				for name in shell.Functions do
					table.insert(all, name)
				end
				table.sort(all)
				return all
			end)()
		local out = {}
		for _, name in list do
			if shell.Functions[name] then
				table.insert(out, `{name} ()`)
			end
		end
		return ok(table.concat(out, "\n"))
	end

	if #names == 0 or printMode then
		local out = {}
		local list = if #names > 0
			then names
			else (function()
				local all = {}
				for name in shell.Vars do
					table.insert(all, name)
				end
				table.sort(all)
				return all
			end)()
		for _, name in list do
			local value = shell:GetVar(name)
			if value ~= nil then
				table.insert(
					out,
					`declare {if shell.Exported[name] then "-x " else ""}{name}={shellQuote(value)}`
				)
			end
		end
		return ok(table.concat(out, "\n"))
	end

	for _, entry in names do
		local name, value = string.match(entry, "^([^=]+)=(.*)$")
		if name then
			shell:SetVar(name, value, export)
			if readonlyMode then
				shell.Readonly[name] = true
			end
		else
			if export then
				shell.Exported[entry] = true
			end
			if readonlyMode then
				shell.Readonly[entry] = true
			end
			if arrayMode then
				shell.Arrays[entry] = { n = 0 }
				shell.Vars[entry] = nil
			end
		end
	end

	return ok("")
end

--// Aliases, functions, commands //--

--[=[
	`alias`: defines or lists aliases.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinAlias(shell, arguments, stdin)
	if #arguments == 0 then
		local names = {}
		for name in shell.Aliases do
			table.insert(names, name)
		end
		table.sort(names)
		local out = {}
		for _, name in names do
			table.insert(out, `alias {name}={shellQuote(shell.Aliases[name])}`)
		end
		return ok(table.concat(out, "\n"))
	end

	local printMode = false
	local i = 1
	if arguments[1] == "-p" then
		printMode = true
		i = 2
	end

	local out = {}
	for j = i, #arguments do
		local name, value = string.match(arguments[j], "^([^=]+)=(.*)$")
		if name then
			shell.Aliases[name] = value
		elseif printMode then
			if shell.Aliases[arguments[j]] then
				table.insert(out, `alias {arguments[j]}={shellQuote(shell.Aliases[arguments[j]])}`)
			end
		elseif shell.Aliases[arguments[j]] then
			table.insert(out, `alias {arguments[j]}={shellQuote(shell.Aliases[arguments[j]])}`)
		else
			return fail(`alias: {arguments[j]}: not found`, 1)
		end
	end

	return ok(table.concat(out, "\n"))
end

--[=[
	`unalias`: removes one alias or every alias.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinUnalias(shell, arguments, stdin)
	if arguments[1] == "-a" then
		shell.Aliases = {}
		return ok("")
	end
	for _, name in arguments do
		if shell.Aliases[name] == nil then
			return fail(`unalias: {name}: not found`, 1)
		end
		shell.Aliases[name] = nil
	end
	return ok("")
end

--[=[
	Describes how a name resolves in the shell.

	@param shell The shell instance.
	@param name The name to look up.
	@return The resulting text.
]=]
local function describe(shell, name: string): string
	if shell.Aliases[name] then
		return `{name} is aliased to '{shell.Aliases[name]}'`
	elseif shell.Functions[name] then
		return `{name} is a function`
	elseif Builtins[name] then
		return `{name} is a shell builtin`
	elseif shell.Service:GetCommand(name) then
		return `{name} is /usr/bin/{name}`
	end
	return `{name}: not found`
end

--[=[
	Returns the kind of a name: alias, function, builtin or command.

	@param shell The shell instance.
	@param name The name to look up.
	@return The resulting text, or nil.
]=]
local function typeKind(shell, name: string): string?
	if shell.Aliases[name] then
		return "alias"
	end
	if shell.Functions[name] then
		return "function"
	end
	if Builtins[name] then
		return "builtin"
	end
	if shell.Service:GetCommand(name) then
		return "command"
	end
	return nil
end

--[=[
	`type`: reports how each name would be interpreted.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinType(shell, arguments, stdin)
	local tOnly = false
	local all = false
	local names = {}

	for _, argument in arguments do
		if argument == "-t" then
			tOnly = true
		elseif argument == "-a" then
			all = true
		elseif argument == "-p" or argument == "-P" then
		elseif string.sub(argument, 1, 1) ~= "-" then
			table.insert(names, argument)
		end
	end

	local out = {}
	local code = 0

	for _, name in names do
		local kind = typeKind(shell, name)
		if not kind then
			code = 1
			if not tOnly then
				table.insert(out, `{name}: not found`)
			end
		elseif tOnly then
			table.insert(out, kind)
		else
			table.insert(out, describe(shell, name))
		end
	end

	return code, table.concat(out, "\n"), ""
end

--[=[
	`command`: bypasses functions and aliases to run a command.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinCommand(shell, arguments, stdin)
	local verbose = nil
	local i = 1

	while i <= #arguments do
		if arguments[i] == "-v" then
			verbose = "short"
		elseif arguments[i] == "-V" then
			verbose = "long"
		elseif arguments[i] == "-p" then
		elseif arguments[i] == "--" then
			i += 1
			break
		elseif string.sub(arguments[i], 1, 1) == "-" then
			return fail(`command: {arguments[i]}: invalid option`, 2)
		else
			break
		end
		i += 1
	end

	if i > #arguments then
		return ok("")
	end

	if verbose then
		local out = {}
		local code = 0
		for j = i, #arguments do
			local kind = typeKind(shell, arguments[j])
			if not kind then
				code = 1
			elseif verbose == "short" then
				table.insert(out, arguments[j])
			else
				table.insert(out, describe(shell, arguments[j]))
			end
		end
		return code, table.concat(out, "\n"), ""
	end

	local words = {}
	for j = i, #arguments do
		table.insert(words, arguments[j])
	end
	return shell:ExecuteCommand(words, stdin, { noAlias = true, noFunction = true })
end

--[=[
	`builtin`: runs a shell builtin directly.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinBuiltin(shell, arguments, stdin)
	if #arguments == 0 then
		return ok("")
	end
	local name = arguments[1]
	local builtin = Builtins[name]
	if not builtin then
		return fail(`builtin: {name}: not a shell builtin`, 1)
	end
	local rest = {}
	for i = 2, #arguments do
		table.insert(rest, arguments[i])
	end
	return builtin.Run(shell, rest, stdin)
end

--// Control flow //--

--[=[
	`exit`: requests that the shell stop with the given status.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinExit(shell, arguments, stdin)
	local code = tonumber(arguments[1]) or shell.Status
	code = math.floor(code) % 256
	shell.ExitRequested = code
	shell.Status = code
	return 0, "", ""
end

--[=[
	`return`: leaves the current function or sourced file.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinReturn(shell, arguments, stdin)
	local code = tonumber(arguments[1]) or shell.Status
	signal("return", math.floor(code) % 256)
	return 0, "", ""
end

--[=[
	`break`: leaves the innermost loop.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinBreak(shell, arguments, stdin)
	signal("break", tonumber(arguments[1]) or 1)
	return 0, "", ""
end

--[=[
	`continue`: starts the next loop iteration.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinContinue(shell, arguments, stdin)
	signal("continue", tonumber(arguments[1]) or 1)
	return 0, "", ""
end

--[=[
	`shift`: drops positional parameters from the front.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinShift(shell, arguments, stdin)
	local count = tonumber(arguments[1]) or 1
	if count < 0 then
		return fail("shift: shift count out of range", 1)
	end
	if count > #shell.Positional then
		return fail("shift: shift count out of range", 1)
	end
	for _ = 1, count do
		table.remove(shell.Positional, 1)
	end
	return ok("")
end

--// eval / source / exec //--

--[=[
	`eval`: parses and runs its arguments as shell input.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinEval(shell, arguments, stdin)
	local line = table.concat(arguments, " ")
	local code, output, errorValue = shell:RunString(line, stdin)
	return code, output, errorValue
end

--[=[
	`source` and `.`: run a command module as shell input.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinSource(shell, arguments, stdin)
	if #arguments == 0 then
		return fail("source: filename argument required", 2)
	end

	local name = arguments[1]
	local script = nil

	if name == "/dev/stdin" or name == "-" then
		script = stdin
	else
		script = shell:GetVar(name)
	end

	if script == nil then
		if string.find(name, "[%s;|&]") then
			script = name
		else
			return fail(`source: {name}: No such file or directory`, 1)
		end
	end

	local saved = shell.Positional
	local positional = {}
	for i = 2, #arguments do
		table.insert(positional, arguments[i])
	end
	if #positional > 0 then
		shell.Positional = positional
	end

	local ok, code, output, errorValue = pcall(shell.RunString, shell, script, stdin)

	shell.Positional = saved

	if not ok then
		if type(code) == "table" and code.__shellControl then
			if code.Kind == "return" then
				return code.Value, code.Output or "", code.Errors or ""
			end
			error(code, 0)
		end
		error(code, 0)
	end

	return code, output, errorValue
end

--[=[
	`exec`: replaces the shell with a command.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinExec(shell, arguments, stdin)
	if #arguments == 0 then
		return ok("")
	end
	local code, output, errorValue = shell:ExecuteCommand(arguments, stdin)
	shell.Status = code
	shell.ExitRequested = code
	return code, output, errorValue
end

--// date / sleep / seq / yes //--

local DATE_FORMATS = {
	["%F"] = "%Y-%m-%d",
	["%T"] = "%H:%M:%S",
	["%R"] = "%H:%M",
	["%D"] = "%m/%d/%y",
	["%r"] = "%I:%M:%S %p",
	["%h"] = "%b",
	["%e"] = "%e",
}

--[=[
	`date`: formats the current time.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinDate(shell, arguments, stdin)
	local utc = false
	local format = nil
	local dateString = nil
	local i = 1

	while i <= #arguments do
		local argument = arguments[i]
		if argument == "-u" or argument == "--utc" or argument == "--universal" then
			utc = true
		elseif argument == "-R" or argument == "--rfc-2822" then
			format = "%a, %d %b %Y %H:%M:%S %z"
		elseif argument == "-I" or argument == "--iso-8601" then
			format = "%Y-%m-%d"
		elseif string.sub(argument, 1, 1) == "+" then
			format = string.sub(argument, 2)
		elseif argument == "-d" or argument == "--date" then
			i += 1
			dateString = arguments[i]
		elseif argument == "-r" or argument == "--reference" then
			i += 1
			dateString = arguments[i]
		elseif argument == "--" then
			i += 1
			break
		else
			format = argument
		end
		i += 1
	end

	if format and format == "%s" then
		return ok(tostring(os.time()))
	end

	local stamp = os.time()
	if dateString then
		local epoch = string.match(dateString, "^@(%d+)$")
		if epoch then
			stamp = tonumber(epoch)
		else
			local y, m, d, hh, mm, ss = string.match(
				dateString,
				"^(%d%d%d%d)%-(%d%d)%-(%d%d)[T ]?(%d?%d?):?(%d?%d?):?(%d?%d?)$"
			)
			if y then
				local dt = os.time({
					year = tonumber(y),
					month = tonumber(m),
					day = tonumber(d),
					hour = tonumber(hh) or 0,
					min = tonumber(mm) or 0,
					sec = tonumber(ss) or 0,
					isdst = false,
				})
				if dt then
					stamp = dt
				end
			end
		end
	end

	if not format then
		format = "%a %b %e %H:%M:%S %Z %Y"
	end

	--[=[
		Replaces every literal occurrence of a substring.

		@param text The text to inspect.
		@param needle The literal substring to find.
		@param replacement The replacement text.
		@return The resulting text.
	]=]
	local function replacePlain(text: string, needle: string, replacement: string): string
		local out = {}
		local start = 1
		while true do
			local index = string.find(text, needle, start, true)
			if not index then
				table.insert(out, string.sub(text, start))
				break
			end
			table.insert(out, string.sub(text, start, index - 1))
			table.insert(out, replacement)
			start = index + #needle
		end
		return table.concat(out)
	end

	for key, value in DATE_FORMATS do
		format = replacePlain(format, key, value)
	end

	local pattern = if utc then "!" .. format else format
	local success, text = pcall(os.date, pattern, stamp)
	if not success then
		return fail(`date: invalid format '{format}'`, 1)
	end
	return ok(text)
end

--[=[
	Parses a duration such as `2h30m` into seconds.

	@param text The text to inspect.
	@return The resulting number, or nil.
]=]
local function parseDuration(text: string): number?
	local total = 0
	local matched = false
	for number, suffix in string.gmatch(text, "(%d+%.?%d*)([smhd]?)") do
		local value = tonumber(number)
		if value then
			matched = true
			if suffix == "m" then
				value *= 60
			elseif suffix == "h" then
				value *= 3600
			elseif suffix == "d" then
				value *= 86400
			end
			total += value
		end
	end
	if not matched then
		return nil
	end
	return total
end

--[=[
	`sleep`: waits for the requested duration.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinSleep(shell, arguments, stdin)
	if #arguments == 0 then
		return fail("sleep: missing operand", 2)
	end

	local total = 0
	for _, argument in arguments do
		local value = parseDuration(argument)
		if not value then
			return fail(`sleep: invalid time interval '{argument}'`, 1)
		end
		total += value
	end

	if total > 300 then
		total = 300
	end
	if total > 0 then
		task.wait(total)
	end
	return ok("")
end

--[=[
	`seq`: prints a numeric sequence.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinSeq(shell, arguments, stdin)
	local separator = "\n"
	local equalWidth = false
	local format = nil
	local numbers = {}
	local i = 1

	while i <= #arguments do
		local argument = arguments[i]
		if argument == "-s" or argument == "--separator" then
			i += 1
			separator = arguments[i] or "\n"
		elseif string.sub(argument, 1, 2) == "-s" then
			separator = string.sub(argument, 3)
		elseif argument == "-w" or argument == "--equal-width" then
			equalWidth = true
		elseif argument == "-f" or argument == "--format" then
			i += 1
			format = arguments[i]
		elseif string.sub(argument, 1, 2) == "-f" then
			format = string.sub(argument, 3)
		elseif argument == "--" then
			i += 1
			while i <= #arguments do
				table.insert(numbers, arguments[i])
				i += 1
			end
			break
		else
			table.insert(numbers, argument)
		end
		i += 1
	end

	if #numbers < 1 or #numbers > 3 then
		return fail("seq: missing operand", 2)
	end

	local first, step, last
	if #numbers == 1 then
		first, step, last = 1, 1, tonumber(numbers[1])
	elseif #numbers == 2 then
		first, step, last = tonumber(numbers[1]), 1, tonumber(numbers[2])
	else
		first, step, last = tonumber(numbers[1]), tonumber(numbers[2]), tonumber(numbers[3])
	end

	if not first or not step or not last or step == 0 then
		return fail("seq: invalid argument", 1)
	end

	local values = {}
	local n = 0
	while (step > 0 and first <= last) or (step < 0 and first >= last) do
		table.insert(values, first)
		first += step
		n += 1
		if n > 10000 then
			return fail("seq: too many values", 1)
		end
	end

	local width = 0
	if equalWidth then
		for _, value in values do
			width = math.max(width, #tostring(value))
		end
	end

	for index, value in values do
		if format then
			local success, text = pcall(string.format, format, value)
			values[index] = if success then text else tostring(value)
		elseif equalWidth then
			values[index] = string.rep("0", math.max(0, width - #tostring(value)))
				.. tostring(value)
		else
			values[index] = tostring(value)
		end
	end

	return ok(table.concat(values, separator))
end

--[=[
	`yes`: repeats a line until the output cap is reached.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinYes(shell, arguments, stdin)
	local text = if #arguments > 0 then table.concat(arguments, " ") else "y"
	local out = {}
	local total = 0
	while total < 8192 do
		table.insert(out, text)
		total += #text + 1
	end
	return ok(table.concat(out, "\n"))
end

--// tee / xargs //--

--[=[
	`tee`: copies standard input to the terminal output.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinTee(shell, arguments, stdin)
	local targets = {}
	for _, argument in arguments do
		if argument ~= "-a" and argument ~= "--append" then
			table.insert(targets, argument)
		end
	end

	local errors = {}
	for _, target in targets do
		local success, errorValue = shell:Redirect(stdin, target)
		if not success then
			table.insert(errors, errorValue)
		end
	end

	local code = if #errors > 0 then 1 else 0
	return code, stdin, table.concat(errors, "\n")
end

--[=[
	Splits NUL-delimited input into fields.

	@param text The text to inspect.
	@return The resulting list.
]=]
local function splitNul(text: string): { string }
	local out = {}
	for piece in string.gmatch(text, "([^%z]*)%z") do
		table.insert(out, piece)
	end
	if #out == 0 then
		for piece in string.gmatch(text, "%S+") do
			table.insert(out, piece)
		end
	end
	return out
end

--[=[
	`xargs`: builds and runs commands from standard input.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinXargs(shell, arguments, stdin)
	local nullDelimited = false
	local replace = nil
	local maxArgs = nil
	local noRun = false
	local trace = false
	local command = {}
	local i = 1

	while i <= #arguments do
		local argument = arguments[i]
		if argument == "-0" or argument == "--null" then
			nullDelimited = true
		elseif argument == "-r" or argument == "--no-run-if-empty" then
			noRun = true
		elseif argument == "-t" or argument == "--verbose" then
			trace = true
		elseif argument == "-n" or argument == "--max-args" then
			i += 1
			maxArgs = tonumber(arguments[i])
		elseif string.sub(argument, 1, 2) == "-n" then
			maxArgs = tonumber(string.sub(argument, 3))
		elseif argument == "-I" or argument == "--replace" then
			i += 1
			replace = arguments[i]
		elseif string.sub(argument, 1, 2) == "-I" then
			replace = string.sub(argument, 3)
		elseif argument == "-d" or argument == "--delimiter" then
			i += 1
			nullDelimited = arguments[i] == "\0"
		elseif string.sub(argument, 1, 2) == "-d" then
			nullDelimited = string.sub(argument, 3) == "\0"
		elseif argument == "--" then
			i += 1
			while i <= #arguments do
				table.insert(command, arguments[i])
				i += 1
			end
			break
		else
			table.insert(command, argument)
		end
		i += 1
	end

	if #command == 0 then
		command = { "echo" }
	end

	local items = if nullDelimited
		then splitNul(stdin)
		else (function()
			local list = {}
			for piece in string.gmatch(stdin, "%S+") do
				table.insert(list, piece)
			end
			return list
		end)()

	if #items == 0 and noRun then
		return ok("")
	end

	local results = {}
	local errors = {}
	local finalCode = 0

	--[=[
		Runs one `xargs` batch.

		@param batch The arguments to pass to one invocation.
		@return The exit status, standard output and standard error.
	]=]
	local function run(batch: { string })
		if replace then
			local words = {}
			for _, word in command do
				table.insert(
					words,
					string.gsub(word, replace, function()
						return batch[1] or ""
					end)
				)
			end
			if trace then
				table.insert(results, table.concat(words, " "))
			end
			local code, output, errorValue = shell:ExecuteCommand(words, "")
			finalCode = code
			if output ~= "" then
				table.insert(results, output)
			end
			if errorValue ~= "" then
				table.insert(errors, errorValue)
			end
		else
			local words = table.clone(command)
			for _, item in batch do
				table.insert(words, item)
			end
			if trace then
				table.insert(results, table.concat(words, " "))
			end
			local code, output, errorValue = shell:ExecuteCommand(words, "")
			finalCode = code
			if output ~= "" then
				table.insert(results, output)
			end
			if errorValue ~= "" then
				table.insert(errors, errorValue)
			end
		end
	end

	if replace then
		for _, item in items do
			run({ item })
		end
	elseif maxArgs and maxArgs > 0 then
		local batch = {}
		for _, item in items do
			table.insert(batch, item)
			if #batch >= maxArgs then
				run(batch)
				batch = {}
			end
		end
		if #batch > 0 then
			run(batch)
		end
	else
		run(items)
	end

	return finalCode, table.concat(results, "\n"), table.concat(errors, "\n")
end

--// jobs //--

--[=[
	`jobs`: lists background jobs.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinJobs(shell, arguments, stdin)
	local out = {}
	for _, job in shell.Jobs do
		local status = if job.Done
			then (if job.Code == 0 then "Done" else `Exit {job.Code}`)
			else "Running"
		table.insert(out, `[{job.Id}] {status}\t{job.Command}`)
	end
	return ok(table.concat(out, "\n"))
end

--[=[
	`wait`: waits for background jobs to finish.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinWait(shell, arguments, stdin)
	local target = tonumber(arguments[1])
	for _, job in shell.Jobs do
		if target == nil or job.Id == target then
			while not job.Done do
				task.wait()
			end
			if target ~= nil then
				return job.Code, "", ""
			end
		end
	end
	return ok("")
end

--[=[
	`disown`: removes jobs from the shell's job table.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinDisown(shell, arguments, stdin)
	for _, job in shell.Jobs do
		job.Disowned = true
	end
	return ok("")
end

--[=[
	Finds a background job by id or the most recent job.

	@param shell The shell instance.
	@param arguments The command arguments.
	@return The matching job, or nil.
]=]
local function findJob(shell, arguments)
	local target = tonumber(arguments[1]) or shell.LastBg
	for _, job in shell.Jobs do
		if job.Id == target and not job.Disowned then
			return job
		end
	end
	return nil
end

--[=[
	`fg`: waits for a job and brings it to the foreground.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinFg(shell, arguments, stdin)
	local job = findJob(shell, arguments)
	if not job then
		return fail("fg: no such job", 1)
	end
	while not job.Done do
		task.wait()
	end
	return job.Code or 0, "", ""
end

--[=[
	`bg`: resumes a stopped job in the background.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinBg(shell, arguments, stdin)
	local job = findJob(shell, arguments)
	if not job then
		return fail("bg: no such job", 1)
	end
	if job.Done then
		return fail("bg: job has terminated", 1)
	end
	return ok(`[{job.Id}] {job.Command} &`)
end

--// history //--

--[=[
	`history`: prints or clears the shell history.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinHistory(shell, arguments, stdin)
	if arguments[1] == "-c" then
		shell.History = {}
		return ok("")
	end

	if arguments[1] == "-d" then
		local index = tonumber(arguments[2])
		if index and shell.History[index] then
			table.remove(shell.History, index)
		end
		return ok("")
	end

	local count = tonumber(arguments[1]) or 20
	local start = math.max(1, #shell.History - count + 1)
	local out = {}
	for i = start, #shell.History do
		table.insert(out, `{i}  {shell.History[i]}`)
	end
	return ok(table.concat(out, "\n"))
end

--// read //--

--[=[
	Splits a line into fields using the current IFS.

	@param line The line to process.
	@param ifs The current IFS value.
	@return The exit status, standard output and standard error.
]=]
local function splitReadFields(line: string, ifs: string): ({ string }, { number })
	if ifs == "" then
		return { line }, { 1 }
	end

	local whitespace = " \t\n"
	local fields = {}
	local starts = {}
	local i = 1
	local length = #line

	--[=[
		Checks whether a character belongs to IFS.

		@param c The character to test.
		@return True when the condition holds.
	]=]
	local function isIfs(c: string): boolean
		return string.find(ifs, c, 1, true) ~= nil
	end

	--[=[
		Checks whether a character is IFS whitespace.

		@param c The character to test.
		@return True when the condition holds.
	]=]
	local function isIfsWhite(c: string): boolean
		return isIfs(c) and string.find(whitespace, c, 1, true) ~= nil
	end

	while i <= length and isIfsWhite(string.sub(line, i, i)) do
		i += 1
	end

	while i <= length do
		local start = i
		local field = {}
		while i <= length do
			local c = string.sub(line, i, i)
			if isIfs(c) then
				break
			end
			table.insert(field, c)
			i += 1
		end
		table.insert(fields, table.concat(field))
		table.insert(starts, start)

		while i <= length and isIfs(string.sub(line, i, i)) do
			local c = string.sub(line, i, i)
			i += 1
			if not isIfsWhite(c) then
				break
			end
		end
	end

	return fields, starts
end

--[=[
	`read`: reads one line into variables.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinRead(shell, arguments, stdin)
	local raw = false
	local arrayName = nil
	local delimiter = "\n"
	local names = {}
	local i = 1

	while i <= #arguments do
		local argument = arguments[i]
		if argument == "-r" then
			raw = true
		elseif argument == "-p" then
			i += 1
		elseif argument == "-d" then
			i += 1
			delimiter = arguments[i] or "\n"
		elseif argument == "-a" then
			i += 1
			arrayName = arguments[i]
		elseif argument == "-n" or argument == "-N" or argument == "-t" then
			i += 1
		elseif argument == "--" then
			i += 1
			break
		elseif string.sub(argument, 1, 1) ~= "-" then
			break
		end
		i += 1
	end

	while i <= #arguments do
		table.insert(names, arguments[i])
		i += 1
	end
	if #names == 0 and not arrayName then
		names = { "REPLY" }
	end

	local line = if delimiter == "\n"
		then (string.match(stdin, "^([^\n]*)") or "")
		else (string.match(stdin, "^([^" .. string.gsub(delimiter, "(%W)", "%%%1") .. "]*)") or "")

	if not raw then
		line = string.gsub(line, "\\(.)", "%1")
	end

	if arrayName then
		local ifs = shell:GetVar("IFS") or " \t\n"
		local fields = splitReadFields(line, ifs)
		local array = { n = #fields }
		for index, value in fields do
			array[index - 1] = value
		end
		shell.Arrays[arrayName] = array
		shell.Vars[arrayName] = nil
		return if stdin == "" then 1 else 0, "", ""
	end

	if names[1] == "REPLY" and #names == 1 then
		shell:SetVar("REPLY", line)
		return if stdin == "" then 1 else 0, "", ""
	end

	local ifs = shell:GetVar("IFS") or " \t\n"
	local fields, starts = splitReadFields(line, ifs)

	for index, name in names do
		if index == #names then
			local remainder = ""
			local start = starts[index]
			if start then
				remainder = string.sub(line, start)
				while #remainder > 0 do
					local last = string.sub(remainder, -1)
					if string.find(ifs, last, 1, true) and string.find(" \t\n", last, 1, true) then
						remainder = string.sub(remainder, 1, -2)
					else
						break
					end
				end
			end
			shell:SetVar(name, remainder)
		else
			shell:SetVar(name, fields[index] or "")
		end
	end

	if stdin == "" then
		return 1, "", ""
	end
	return 0, "", ""
end

--[=[
	`mapfile` and `readarray`: read lines into an array.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinMapfile(shell, arguments, stdin)
	local name = "MAPFILE"
	local i = 1

	while i <= #arguments do
		local argument = arguments[i]
		if argument == "-t" then
			i += 1
		elseif
			argument == "-n"
			or argument == "-O"
			or argument == "-s"
			or argument == "-c"
			or argument == "-d"
		then
			i += 2
		elseif string.sub(argument, 1, 1) ~= "-" then
			name = argument
			i += 1
			break
		else
			i += 1
		end
	end

	local lines = Text.lines(stdin)
	local array = { n = #lines }
	for index, line in lines do
		array[index - 1] = line
	end

	shell.Arrays[name] = array
	shell.Vars[name] = nil
	return ok("")
end

--// env / misc //--
--[=[
	`env`: runs a command with temporary environment variables.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinEnv(shell, arguments, stdin)
	local savedVars = table.clone(shell.Vars)
	local savedExported = table.clone(shell.Exported)

	--[=[
		Restores the environment saved by `env`.
	]=]
	local function restore()
		shell.Vars = savedVars
		shell.Exported = savedExported
	end

	if #arguments == 0 then
		local names = {}
		for name in shell.Exported do
			table.insert(names, name)
		end
		table.sort(names)
		local out = {}
		for _, name in names do
			local value = shell:GetVar(name)
			if value ~= nil then
				table.insert(out, `{name}={value}`)
			end
		end
		return ok(table.concat(out, "\n"))
	end

	local i = 1
	while i <= #arguments do
		local name, value = string.match(arguments[i], "^([^=]+)=(.*)$")
		if name then
			shell:SetVar(name, value, true)
			i += 1
		elseif arguments[i] == "-i" or arguments[i] == "--ignore-environment" then
			shell.Vars = {}
			shell.Exported = {}
			i += 1
		elseif arguments[i] == "-u" or arguments[i] == "--unset" then
			i += 1
			shell.Vars[arguments[i]] = nil
			shell.Exported[arguments[i]] = nil
			i += 1
		else
			break
		end
	end

	if i > #arguments then
		local code, output, errorValue = builtinEnv(shell, {}, stdin)
		restore()
		return code, output, errorValue
	end

	local words = {}
	for j = i, #arguments do
		table.insert(words, arguments[j])
	end
	local code, output, errorValue = shell:ExecuteCommand(words, stdin)
	restore()
	return code, output, errorValue
end

--[=[
	`pwd`: prints the current directory.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinPwd(shell, arguments, stdin)
	return ok(shell:GetVar("PWD") or "/")
end

--[=[
	`cd`: reports that this terminal has no filesystem.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinCd(shell, arguments, stdin)
	return fail("cd: there is no filesystem in this terminal", 1)
end

--[=[
	`let`: evaluates arithmetic expressions.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinLet(shell, arguments, stdin)
	if #arguments == 0 then
		return 1, "", ""
	end
	local value = 0
	local success, result = pcall(function()
		return shell:Arithmetic(table.concat(arguments, " "))
	end)
	if not success then
		return fail(tostring(result), 1)
	end
	value = result
	if value ~= 0 then
		return 0, "", ""
	end
	return 1, "", ""
end

--[=[
	`cat`: copies standard input or rejects file operands.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinCat(shell, arguments, stdin)
	if #arguments > 0 then
		return fail(`cat: {arguments[1]}: No such file or directory`, 1)
	end
	return ok(stdin)
end

--[=[
	`basename`: strips the directory and optional suffix from a path.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinBasename(shell, arguments, stdin)
	if #arguments == 0 then
		return fail("basename: missing operand", 2)
	end

	local path = arguments[1]
	path = string.gsub(path, "/+$", "")
	if path == "" then
		path = "/"
	end
	local name = string.match(path, "([^/]+)$") or path

	if
		arguments[2]
		and arguments[2] ~= ""
		and string.sub(name, -#arguments[2]) == arguments[2]
		and #name > #arguments[2]
	then
		name = string.sub(name, 1, #name - #arguments[2])
	end

	return ok(name)
end

--[=[
	`dirname`: returns the directory part of a path.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinDirname(shell, arguments, stdin)
	if #arguments == 0 then
		return fail("dirname: missing operand", 2)
	end

	local path = string.gsub(arguments[1], "/+$", "")
	local directory = string.match(path, "^(.*)/[^/]*$")
	if not directory then
		return ok(".")
	end
	if directory == "" then
		return ok("/")
	end
	return ok(directory)
end

local BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

--[=[
	Encodes bytes as Base64.

	@param input The input to process.
	@param wrap The line width, or nil for no wrapping.
	@return The resulting text.
]=]
local function base64Encode(input: string, wrap: number?): string
	local out = {}
	local i = 1

	while i <= #input do
		local a = string.byte(input, i) or 0
		local b = string.byte(input, i + 1)
		local c = string.byte(input, i + 2)

		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		local c1 = math.floor(n / 262144) % 64
		local c2 = math.floor(n / 4096) % 64
		local c3 = math.floor(n / 64) % 64
		local c4 = n % 64

		table.insert(out, string.sub(BASE64_ALPHABET, c1 + 1, c1 + 1))
		table.insert(out, string.sub(BASE64_ALPHABET, c2 + 1, c2 + 1))
		table.insert(out, if b then string.sub(BASE64_ALPHABET, c3 + 1, c3 + 1) else "=")
		table.insert(out, if c then string.sub(BASE64_ALPHABET, c4 + 1, c4 + 1) else "=")

		i += 3
	end

	local encoded = table.concat(out)
	if wrap and wrap > 0 then
		local wrapped = {}
		for start = 1, #encoded, wrap do
			table.insert(wrapped, string.sub(encoded, start, start + wrap - 1))
		end
		return table.concat(wrapped, "\n")
	end
	return encoded
end

--[=[
	Decodes Base64 into bytes.

	@param input The input to process.
	@return The exit status, standard output and standard error.
]=]
local function base64Decode(input: string): (string?, string?)
	local clean = string.gsub(input, "%s+", "")
	local map = {}
	for i = 1, #BASE64_ALPHABET do
		map[string.sub(BASE64_ALPHABET, i, i)] = i - 1
	end

	local out = {}
	local i = 1
	while i <= #clean do
		local c1 = string.sub(clean, i, i)
		local c2 = string.sub(clean, i + 1, i + 1)
		local c3 = string.sub(clean, i + 2, i + 2)
		local c4 = string.sub(clean, i + 3, i + 3)

		if c1 == "" or c2 == "" then
			break
		end
		local n1, n2 = map[c1], map[c2]
		if not n1 or not n2 then
			return nil, "invalid input"
		end

		local n3 = if c3 == "=" or c3 == "" then 0 else map[c3]
		local n4 = if c4 == "=" or c4 == "" then 0 else map[c4]
		if n3 == nil or n4 == nil then
			return nil, "invalid input"
		end

		local n = n1 * 262144 + n2 * 4096 + n3 * 64 + n4
		table.insert(out, string.char(math.floor(n / 65536) % 256))
		if c3 ~= "=" and c3 ~= "" then
			table.insert(out, string.char(math.floor(n / 256) % 256))
		end
		if c4 ~= "=" and c4 ~= "" then
			table.insert(out, string.char(n % 256))
		end

		i += 4
	end

	return table.concat(out), nil
end

--[=[
	`base64`: encodes or decodes standard input.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinBase64(shell, arguments, stdin)
	local decode = false
	local wrap = 76
	local i = 1

	while i <= #arguments do
		local argument = arguments[i]
		if argument == "-d" or argument == "--decode" then
			decode = true
		elseif argument == "-w" or argument == "--wrap" then
			i += 1
			wrap = tonumber(arguments[i]) or 76
		elseif string.sub(argument, 1, 2) == "-w" then
			wrap = tonumber(string.sub(argument, 3)) or 76
		elseif argument == "-i" or argument == "--ignore-garbage" then
		elseif argument == "--" then
			i += 1
			break
		else
			break
		end
		i += 1
	end

	if i <= #arguments then
		return fail(`base64: {arguments[i]}: No such file or directory`, 1)
	end

	if decode then
		local decoded, errorValue = base64Decode(stdin)
		if not decoded then
			return fail(`base64: {errorValue}`, 1)
		end
		return ok(decoded)
	end

	return ok(base64Encode(stdin, wrap))
end

--[=[
	`local`: declares variables in the current function frame.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinLocal(shell, arguments, stdin)
	if #shell.LocalFrames == 0 then
		return fail("local: can only be used in a function", 1)
	end

	for _, argument in arguments do
		if string.sub(argument, 1, 1) == "-" then
			continue
		end

		local name, value = string.match(argument, "^([^=]+)=(.*)$")
		if name then
			if not isIdentifier(name) then
				return fail(`local: '{name}': not a valid identifier`, 1)
			end
			shell:SetLocal(name, value)
		else
			if not isIdentifier(argument) then
				return fail(`local: '{argument}': not a valid identifier`, 1)
			end
			shell:SetLocal(argument, "")
		end
	end

	return ok("")
end

--[=[
	`readonly`: marks variables as read-only.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinReadonly(shell, arguments, stdin)
	shell.Readonly = shell.Readonly or {}
	for _, argument in arguments do
		local name, value = string.match(argument, "^([^=]+)=(.*)$")
		if name then
			shell:SetVar(name, value)
			shell.Readonly[name] = true
		elseif argument ~= "-p" and argument ~= "-f" then
			shell.Readonly[argument] = true
		end
	end
	return ok("")
end

--[=[
	`shopt`: reports shell options.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinShopt(shell, arguments, stdin)
	if #arguments == 0 then
		return ok("dotglob\toff\nexpand_aliases\ton\nglobstar\toff\nnullglob\toff\n")
	end
	return ok("")
end

--[=[
	`hash`: accepted for compatibility; there is no path cache.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinHash(shell, arguments, stdin)
	return ok("")
end

--[=[
	`trap`: registers or lists signal handlers.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinTrap(shell, arguments, stdin)
	if #arguments == 0 then
		local out = {}
		for sig, action in shell.Traps or {} do
			table.insert(out, `trap -- '{action}' {sig}`)
		end
		return ok(table.concat(out, "\n"))
	end

	local action = arguments[1]

	if action == "-l" then
		return ok("EXIT HUP INT QUIT ILL TRAP ABRT BUS FPE KILL USR1 SEGV USR2 PIPE ALRM TERM")
	end

	if action == "-p" then
		local out = {}
		local wanted = if arguments[2] then arguments[2] else nil
		for sig, value in shell.Traps or {} do
			if not wanted or sig == wanted or (wanted == "0" and sig == "EXIT") then
				table.insert(out, `trap -- '{value}' {sig}`)
			end
		end
		return ok(table.concat(out, "\n"))
	end

	shell.Traps = shell.Traps or {}

	for index = 2, #arguments do
		local signal = arguments[index]
		if signal == "0" then
			signal = "EXIT"
		end
		if action == "-" then
			shell.Traps[signal] = nil
		else
			shell.Traps[signal] = action
		end
	end

	return ok("")
end

--[=[
	`umask`: reports the fixed mask; there is no filesystem.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinUmask(shell, arguments, stdin)
	return ok("0022")
end

--[=[
	`ulimit`: reports the fixed limit; there is no process table.

	@param shell The shell instance.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
local function builtinUlimit(shell, arguments, stdin)
	return ok("unlimited")
end

--// metadata //--

--[=[
	Builds the metadata table for a builtin.

	@param name The name to look up.
	@param aliases The aliases to register.
	@param description The description to show.
	@param arguments The command arguments.
	@return The builtin metadata table.
]=]
local function describeBuiltin(name, aliases, description, arguments)
	return {
		Name = name,
		Aliases = aliases or {},
		Description = description,
		Args = arguments or {},
		Permission = "Any",
		IsBuiltin = true,
	}
end

local definitions = {
	{
		Name = ":",
		Description = "Do nothing, successfully.",
		--[=[
			Returns success without producing output.

			@return The exit status, standard output and standard error.
		]=]
		Run = function()
			return 0, "", ""
		end,
	},
	{
		Name = "true",
		Description = "Do nothing, successfully.",
		--[=[
			Returns success without producing output.

			@return The exit status, standard output and standard error.
		]=]
		Run = function()
			return 0, "", ""
		end,
	},
	{
		Name = "false",
		Description = "Do nothing, unsuccessfully.",
		--[=[
			Returns failure without producing output.

			@return The exit status, standard output and standard error.
		]=]
		Run = function()
			return 1, "", ""
		end,
	},
	{
		Name = "echo",
		Aliases = {},
		Description = "Write arguments to standard output.",
		Run = builtinEcho,
	},
	{
		Name = "printf",
		Description = "Format and print data.",
		Run = builtinPrintf,
	},
	{
		Name = "test",
		Aliases = {},
		Description = "Evaluate a conditional expression.",
		--[=[
			Do nothing, successfully.

			@param shell The shell instance.
			@param arguments The command arguments.
			@param stdin The piped standard input.
			@return A status message when the command succeeds.
		]=]
		Run = function(shell, arguments, stdin)
			return builtinTest(shell, arguments, stdin, false, false)
		end,
	},
	{
		Name = "[",
		Description = "Evaluate a conditional expression (closing ] required).",
		--[=[
			Do nothing, successfully.

			@param shell The shell instance.
			@param arguments The command arguments.
			@param stdin The piped standard input.
			@return A status message when the command succeeds.
		]=]
		Run = function(shell, arguments, stdin)
			return builtinTest(shell, arguments, stdin, true, false)
		end,
	},
	{
		Name = "[[",
		Description = "Evaluate an extended conditional expression.",
		--[=[
			Do nothing, successfully.

			@param shell The shell instance.
			@param arguments The command arguments.
			@param stdin The piped standard input.
			@return A status message when the command succeeds.
		]=]
		Run = function(shell, arguments, stdin)
			return builtinTest(shell, arguments, stdin, false, true)
		end,
	},
	{
		Name = "export",
		Description = "Mark variables for export to child commands.",
		Run = builtinExport,
	},
	{
		Name = "unset",
		Description = "Remove variables or functions.",
		Run = builtinUnset,
	},
	{
		Name = "set",
		Description = "Set shell options and positional parameters.",
		Run = builtinSet,
	},
	{
		Name = "declare",
		Aliases = { "typeset" },
		Description = "Declare variables and functions.",
		Run = builtinDeclare,
	},
	{
		Name = "local",
		Description = "Create a function-local variable.",
		Run = builtinLocal,
	},
	{
		Name = "alias",
		Description = "Define or display aliases.",
		Run = builtinAlias,
	},
	{
		Name = "unalias",
		Description = "Remove aliases.",
		Run = builtinUnalias,
	},
	{
		Name = "type",
		Description = "Describe how a name would be interpreted.",
		Run = builtinType,
	},
	{
		Name = "which",
		Description = "Locate a command.",
		--[=[
			Do nothing, successfully.

			@param shell The shell instance.
			@param arguments The command arguments.
			@param stdin The piped standard input.
			@return A status message when the command succeeds.
		]=]
		Run = function(shell, arguments, stdin)
			local out = {}
			local code = 0
			for _, name in arguments do
				local kind = typeKind(shell, name)
				if kind then
					table.insert(out, name)
				else
					code = 1
				end
			end
			return code, table.concat(out, "\n"), ""
		end,
	},
	{
		Name = "command",
		Description = "Run a command, bypassing functions and aliases.",
		Run = builtinCommand,
	},
	{
		Name = "builtin",
		Description = "Run a shell builtin.",
		Run = builtinBuiltin,
	},
	{
		Name = "exit",
		Description = "Exit the shell.",
		Run = builtinExit,
	},
	{
		Name = "return",
		Description = "Return from a shell function.",
		Run = builtinReturn,
	},
	{
		Name = "break",
		Description = "Exit a loop.",
		Run = builtinBreak,
	},
	{
		Name = "continue",
		Description = "Resume the next loop iteration.",
		Run = builtinContinue,
	},
	{
		Name = "shift",
		Description = "Shift positional parameters.",
		Run = builtinShift,
	},
	{
		Name = "eval",
		Description = "Evaluate arguments as a shell command.",
		Run = builtinEval,
	},
	{
		Name = "source",
		Aliases = { "." },
		Description = "Evaluate a script stored in a variable.",
		Run = builtinSource,
	},
	{
		Name = "exec",
		Description = "Replace the shell with a command.",
		Run = builtinExec,
	},
	{
		Name = "date",
		Description = "Display the current date and time.",
		Run = builtinDate,
	},
	{
		Name = "sleep",
		Description = "Delay for a specified amount of time.",
		Run = builtinSleep,
	},
	{
		Name = "seq",
		Description = "Print a sequence of numbers.",
		Run = builtinSeq,
	},
	{
		Name = "yes",
		Description = "Print a string repeatedly.",
		Run = builtinYes,
	},
	{
		Name = "tee",
		Description = "Copy standard input to a player terminal and to standard output.",
		Run = builtinTee,
	},
	{
		Name = "xargs",
		Description = "Build and run commands from standard input.",
		Run = builtinXargs,
	},
	{
		Name = "jobs",
		Description = "List background jobs.",
		Run = builtinJobs,
	},
	{
		Name = "fg",
		Description = "Wait for a background job.",
		Run = builtinFg,
	},
	{
		Name = "bg",
		Description = "Show a background job.",
		Run = builtinBg,
	},
	{
		Name = "wait",
		Description = "Wait for background jobs.",
		Run = builtinWait,
	},
	{
		Name = "disown",
		Description = "Forget background jobs.",
		Run = builtinDisown,
	},
	{
		Name = "history",
		Aliases = { "hist" },
		Description = "Display the command history.",
		Run = builtinHistory,
	},
	{
		Name = "cat",
		Description = "Concatenate stdin (there is no filesystem).",
		Run = builtinCat,
	},
	{
		Name = "basename",
		Description = "Strip directory and suffix from a path string.",
		Run = builtinBasename,
	},
	{
		Name = "dirname",
		Description = "Strip the last component from a path string.",
		Run = builtinDirname,
	},
	{
		Name = "base64",
		Description = "Base64 encode or decode stdin.",
		Run = builtinBase64,
	},
	{
		Name = "read",
		Description = "Read a line from standard input into variables.",
		Run = builtinRead,
	},
	{
		Name = "mapfile",
		Aliases = { "readarray" },
		Description = "Read lines from standard input into an array.",
		Run = builtinMapfile,
	},
	{
		Name = "env",
		Description = "Display the environment or run a command in it.",
		Run = builtinEnv,
	},
	{
		Name = "printenv",
		Description = "Print environment variables.",
		--[=[
			Do nothing, successfully.

			@param shell The shell instance.
			@param arguments The command arguments.
			@param stdin The piped standard input.
			@return A status message when the command succeeds.
		]=]
		Run = function(shell, arguments, stdin)
			if #arguments == 0 then
				return builtinEnv(shell, {}, stdin)
			end
			local out = {}
			local code = 0
			for _, name in arguments do
				local value = shell:GetVar(name)
				if shell.Exported[name] and value ~= nil then
					table.insert(out, value)
				else
					code = 1
				end
			end
			return code, table.concat(out, "\n"), ""
		end,
	},
	{
		Name = "pwd",
		Description = "Print the current directory.",
		Run = builtinPwd,
	},
	{
		Name = "cd",
		Description = "Change directory (unavailable: no filesystem).",
		Run = builtinCd,
	},
	{
		Name = "let",
		Description = "Evaluate arithmetic expressions.",
		Run = builtinLet,
	},
	{
		Name = "readonly",
		Aliases = { "declare -r" },
		Description = "Mark variables as read-only.",
		Run = builtinReadonly,
	},
	{
		Name = "shopt",
		Description = "Toggle shell options.",
		Run = builtinShopt,
	},
	{
		Name = "hash",
		Description = "Remember command locations.",
		Run = builtinHash,
	},
	{
		Name = "trap",
		Description = "Set signal handlers.",
		Run = builtinTrap,
	},
	{
		Name = "umask",
		Description = "Display or set the file mode mask.",
		Run = builtinUmask,
	},
	{
		Name = "ulimit",
		Description = "Display resource limits.",
		Run = builtinUlimit,
	},
}

for _, definition in definitions do
	local run = definition.Run
	definition.Run = run
	local entry = {
		Name = definition.Name,
		Aliases = definition.Aliases or {},
		Description = definition.Description or "",
		Args = definition.Args or {},
		Permission = "Any",
		Category = "Shell",
		IsBuiltin = true,
		Run = run,
	}
	Builtins[definition.Name] = entry
	for _, alias in definition.Aliases or {} do
		if string.match(alias, "^[%a_][%w_]*$") or alias == "." then
			Builtins[alias] = entry
		end
	end
end

Builtins["."] = Builtins["source"]

return Builtins
