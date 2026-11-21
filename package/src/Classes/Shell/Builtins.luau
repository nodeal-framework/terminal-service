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

local function ok(text: string?): (number, string, string)
	return 0, text or "", ""
end

local function fail(message: string, code: number?): (number, string, string)
	return code or 1, "", message
end

local function signal(kind: string, value: number?)
	error({ __shellControl = true, Kind = kind, Value = value or 0 }, 0)
end

local function shellQuote(value: string): string
	return "'" .. string.gsub(value, "'", "'\\''") .. "'"
end

local function isIdentifier(name: string): boolean
	return string.match(name, "^[%a_][%w_]*$") ~= nil
end

--// echo / printf //--

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
				["a"] = "\a", ["b"] = "\b", ["e"] = "\27", ["E"] = "\27",
				["f"] = "\f", ["n"] = "\n", ["r"] = "\r", ["t"] = "\t",
				["v"] = "\v", ["\\"] = "\\", ["0"] = "\0",
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

local function builtinEcho(shell, args, stdin)
	local newline = true
	local escapes = false
	local i = 1

	while i <= #args do
		local arg = args[i]
		if arg == "-n" then
			newline = false
		elseif arg == "-e" then
			escapes = true
		elseif arg == "-E" then
			escapes = false
		elseif arg == "--" then
			i += 1
			break
		elseif string.match(arg, "^%-[neE]+$") then
			for j = 2, #arg do
				local c = string.sub(arg, j, j)
				if c == "n" then newline = false
				elseif c == "e" then escapes = true
				elseif c == "E" then escapes = false end
			end
		else
			break
		end
		i += 1
	end

	local parts = {}
	for j = i, #args do
		table.insert(parts, args[j])
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

local function toBase(value: number, base: number, upper: boolean): string
	local digits = if upper then "0123456789ABCDEF" else "0123456789abcdef"
	local n = math.floor(math.abs(value))
	if n == 0 then return "0" end
	local out = {}
	while n > 0 do
		local d = n % base
		table.insert(out, 1, string.sub(digits, d + 1, d + 1))
		n = math.floor(n / base)
	end
	return table.concat(out)
end

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

local function builtinPrintf(shell, args, stdin)
	if #args == 0 then
		return fail("printf: usage: printf FORMAT [ARGUMENT]...", 2)
	end

	local varName = nil
	local start = 1
	while start <= #args do
		if args[start] == "-v" then
			start += 1
			varName = args[start]
			start += 1
		elseif args[start] == "--" then
			start += 1
			break
		else
			break
		end
	end

	local format = args[start]
	if format == nil then
		return fail("printf: usage: printf FORMAT [ARGUMENT]...", 2)
	end

	local values = {}
	for i = start + 1, #args do
		table.insert(values, args[i])
	end

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
						["n"] = "\n", ["t"] = "\t", ["r"] = "\r", ["a"] = "\a",
						["b"] = "\b", ["f"] = "\f", ["v"] = "\v", ["\\"] = "\\",
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
					if precision then text = string.sub(text, 1, precision) end
					if width > #text then
						text = if string.find(flags, "-", 1, true) then text .. string.rep(" ", width - #text) else string.rep(" ", width - #text) .. text
					end
					table.insert(out, text)
				elseif conversion == "c" then
					local text = string.sub(tostring(value or ""), 1, 1)
					if width > 1 then
						text = if string.find(flags, "-", 1, true) then text .. string.rep(" ", width - 1) else string.rep(" ", width - 1) .. text
					end
					table.insert(out, text)
				elseif conversion == "d" or conversion == "i" or conversion == "u"
					or conversion == "o" or conversion == "x" or conversion == "X" then
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
						if conversion == "x" then text = "0x" .. text
						elseif conversion == "X" then text = "0X" .. text
						elseif conversion == "o" then text = "0" .. text end
					end
					table.insert(out, padNumber(text, width, flags, negative))
				elseif conversion == "f" or conversion == "F" or conversion == "e"
					or conversion == "E" or conversion == "g" or conversion == "G" then
					local number = tonumber(value) or 0
					local spec = "%" .. flags .. (if width > 0 then tostring(width) else "") .. (if precision then "." .. precision else "") .. conversion
					local success, text = pcall(string.format, spec, number)
					table.insert(out, if success then text else tostring(number))
				elseif conversion == "n" then
					-- ignore
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

		if #values == 0 then break end
		if valueIndex.n == before then break end
	until valueIndex.n >= #values or passes > 64

	local text = table.concat(result)
	if varName then
		shell:SetVar(varName, text)
		return 0, "", ""
	end
	return ok(text)
end

--// test / [ //--

local function testUnary(op: string, value: string, shell): boolean?
	if op == "-n" then return value ~= "" end
	if op == "-z" then return value == "" end
	if op == "-v" then return shell:GetVar(value) ~= nil end
	if op == "-o" then
		local name = string.match(value, "^%+?o$")
		if name then return true end
		return shell.Options[value] == true
	end
	if op == "-t" then return false end
	if op == "-e" or op == "-a" or op == "-f" or op == "-d" or op == "-r"
		or op == "-w" or op == "-x" or op == "-s" or op == "-L" or op == "-h"
		or op == "-p" or op == "-S" or op == "-b" or op == "-c" or op == "-g"
		or op == "-u" or op == "-k" or op == "-O" or op == "-G" or op == "-N" then
		-- no filesystem: everything but -e/-f/-d is false, and those are false too
		return false
	end
	return nil
end

local function testBinary(left: string, op: string, right: string): boolean?
	if op == "=" or op == "==" then return left == right end
	if op == "!=" then return left ~= right end
	if op == "<" then return left < right end
	if op == ">" then return left > right end

	local a = tonumber(left)
	local b = tonumber(right)
	if op == "-eq" then return a ~= nil and b ~= nil and a == b end
	if op == "-ne" then return a ~= nil and b ~= nil and a ~= b end
	if op == "-lt" then return a ~= nil and b ~= nil and a < b end
	if op == "-le" then return a ~= nil and b ~= nil and a <= b end
	if op == "-gt" then return a ~= nil and b ~= nil and a > b end
	if op == "-ge" then return a ~= nil and b ~= nil and a >= b end
	return nil
end

local function evalTest(args, shell, patternMode: boolean): (boolean, string?)
	local pos = 1

	local function peek() return args[pos] end
	local function advance()
		local v = args[pos]
		pos += 1
		return v
	end

	local parseOr, parseAnd, parseNot, parsePrimary

	function parsePrimary()
		local token = peek()
		if token == nil then
			return nil, "argument expected"
		end

		if token == "(" then
			advance()
			local value, err = parseOr()
			if value == nil then return nil, err end
			if peek() ~= ")" then return nil, "')' expected" end
			advance()
			return value
		end

		-- unary
		local unary = testUnary(token, args[pos + 1] or "", shell)
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

		-- binary
		if patternMode and (op == "==" or op == "=") then
			advance()
			local right = advance()
			if right == nil then return nil, "argument expected" end
			return Glob.match(left, right)
		elseif patternMode and op == "!=" then
			advance()
			local right = advance()
			if right == nil then return nil, "argument expected" end
			return not Glob.match(left, right)
		elseif patternMode and op == "=~" then
			advance()
			local right = advance()
			if right == nil then return nil, "argument expected" end
			local ok, matcher = pcall(Regex.compile, right)
			if not ok then return nil, "invalid regular expression" end
			return matcher:Test(left)
		else
			local result = testBinary(left, op, peek() and args[pos + 1] or "")
			if result ~= nil then
				advance()
				advance()
				return result
			end
		end

		return left ~= ""
	end

	function parseNot()
		if peek() == "!" then
			advance()
			local value, err = parseNot()
			if value == nil then return nil, err end
			return not value
		end
		return parsePrimary()
	end

	function parseAnd()
		local value, err = parseNot()
		if value == nil then return nil, err end
		while peek() == "-a" do
			advance()
			local right, err2 = parseNot()
			if right == nil then return nil, err2 end
			value = value and right
		end
		return value
	end

	function parseOr()
		local value, err = parseAnd()
		if value == nil then return nil, err end
		while peek() == "-o" do
			advance()
			local right, err2 = parseAnd()
			if right == nil then return nil, err2 end
			value = value or right
		end
		return value
	end

	local value, err = parseOr()
	if value == nil then
		return false, err
	end
	if pos <= #args then
		return false, `too many arguments near '{args[pos]}'`
	end
	return value
end

local function builtinTest(shell, args, stdin, bracket: boolean?, extended: boolean?)
	local list = args
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
		-- [[ ... ]] supports && and || as words
		for i, value in list do
			if value == "&&" then list[i] = "-a"
			elseif value == "||" then list[i] = "-o" end
		end
	end

	if #list == 0 then
		return 1, "", ""
	end

	local result, err = evalTest(list, shell, extended == true)
	if err then
		return fail(`{(bracket and "[" or "test")}: {err}`, 2)
	end
	if result then
		return 0, "", ""
	end
	return 1, "", ""
end

--// Variables //--

local function printVar(shell, name: string, exportedOnly: boolean?): string?
	if exportedOnly and not shell.Exported[name] then return nil end
	local value = shell:GetVar(name)
	if value == nil then return nil end
	return `{name}={shellQuote(value)}`
end

local function builtinExport(shell, args, stdin)
	local printMode = false
	local unexport = false
	local i = 1
	while i <= #args and string.sub(args[i], 1, 1) == "-" and args[i] ~= "-" do
		if args[i] == "-p" then printMode = true
		elseif args[i] == "-n" then unexport = true
		elseif args[i] == "--" then i += 1; break
		else return fail(`export: {args[i]}: invalid option`, 2) end
		i += 1
	end

	if printMode or i > #args then
		local names = {}
		for name in shell.Exported do table.insert(names, name) end
		table.sort(names)
		local out = {}
		for _, name in names do
			table.insert(out, `declare -x {printVar(shell, name, true) or name}`)
		end
		return ok(table.concat(out, "\n"))
	end

	for j = i, #args do
		local name, value = string.match(args[j], "^([^=]+)=(.*)$")
		if name then
			if not isIdentifier(name) then
				return fail(`export: '{name}': not a valid identifier`, 1)
			end
			shell:SetVar(name, value, not unexport)
			if unexport then shell.Exported[name] = nil end
		else
			if not isIdentifier(args[j]) then
				return fail(`export: '{args[j]}': not a valid identifier`, 1)
			end
			if unexport then
				shell.Exported[args[j]] = nil
			else
				shell.Exported[args[j]] = true
			end
		end
	end

	return ok("")
end

local function builtinUnset(shell, args, stdin)
	local functions = false
	local i = 1
	while i <= #args do
		if args[i] == "-f" then functions = true
		elseif args[i] == "-v" then functions = false
		elseif args[i] == "--" then i += 1; break
		elseif string.sub(args[i], 1, 1) == "-" then return fail(`unset: {args[i]}: invalid option`, 2)
		else break end
		i += 1
	end

	for j = i, #args do
		if functions then
			shell.Functions[args[j]] = nil
		else
			if shell.Readonly[args[j]] then
				return fail(`unset: {args[j]}: cannot unset: readonly variable`, 1)
			end
			shell:SetVar(args[j], nil)
			shell.Arrays[args[j]] = nil
			shell.Exported[args[j]] = nil
		end
	end
	return ok("")
end

local OPTION_NAMES = {
	pipefail = true, errexit = true, nounset = true, xtrace = true,
	noglob = true, noclobber = true, monitor = true, history = true,
	interactive = true, emacs = true, vi = true, allexport = true,
}

local function builtinSet(shell, args, stdin)
	if #args == 0 then
		local names = {}
		for name in shell.Vars do table.insert(names, name) end
		table.sort(names)
		local out = {}
		for _, name in names do
			table.insert(out, `{name}={shellQuote(shell.Vars[name])}`)
		end
		return ok(table.concat(out, "\n"))
	end

	local i = 1
	local positional = nil

	while i <= #args do
		local arg = args[i]
		if arg == "--" then
			positional = {}
			i += 1
			while i <= #args do table.insert(positional, args[i]); i += 1 end
			break
		elseif arg == "-o" or arg == "+o" then
			local enable = arg == "-o"
			i += 1
			local name = args[i]
			if name == nil then
				local out = {}
				local options = {}
				for opt in OPTION_NAMES do table.insert(options, opt) end
				table.sort(options)
				for _, opt in options do
					table.insert(out, `{opt}\t{if shell.Options[opt] then "on" else "off"}`)
				end
				return ok(table.concat(out, "\n"))
			end
			if not OPTION_NAMES[name] then return fail(`set: {name}: invalid option name`, 2) end
			shell.Options[name] = enable
			i += 1
		elseif string.match(arg, "^[%-+]%a+$") then
			local enable = string.sub(arg, 1, 1) == "-"
			for j = 2, #arg do
				local c = string.sub(arg, j, j)
				local map = { e = "errexit", u = "nounset", x = "xtrace", f = "noglob", C = "noclobber", m = "monitor", h = "history", a = "allexport" }
				if map[c] then shell.Options[map[c]] = enable
				elseif c == "o" then
					-- handled above with a separate word
				else
					return fail(`set: -{c}: invalid option`, 2)
				end
			end
			i += 1
		else
			positional = {}
			while i <= #args do table.insert(positional, args[i]); i += 1 end
			break
		end
	end

	if positional then
		shell.Positional = positional
	end
	return ok("")
end

local function builtinDeclare(shell, args, stdin)
	local export = false
	local printMode = false
	local functionMode = false
	local readonlyMode = false
	local arrayMode = false
	local names = {}

	for _, arg in args do
		if arg == "-x" then export = true
		elseif arg == "-p" then printMode = true
		elseif arg == "-f" then functionMode = true
		elseif arg == "-r" then readonlyMode = true
		elseif arg == "-a" or arg == "-A" then arrayMode = true
		elseif string.sub(arg, 1, 1) ~= "-" then
			table.insert(names, arg)
		end
	end

	if functionMode then
		local list = if #names > 0 then names else (function()
			local all = {}
			for name in shell.Functions do table.insert(all, name) end
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
		local list = if #names > 0 then names else (function()
			local all = {}
			for name in shell.Vars do table.insert(all, name) end
			table.sort(all)
			return all
		end)()
		for _, name in list do
			local value = shell:GetVar(name)
			if value ~= nil then
				table.insert(out, `declare {if shell.Exported[name] then "-x " else ""}{name}={shellQuote(value)}`)
			end
		end
		return ok(table.concat(out, "\n"))
	end

	for _, entry in names do
		local name, value = string.match(entry, "^([^=]+)=(.*)$")
		if name then
			shell:SetVar(name, value, export)
			if readonlyMode then shell.Readonly[name] = true end
		else
			if export then shell.Exported[entry] = true end
			if readonlyMode then shell.Readonly[entry] = true end
			if arrayMode then
				shell.Arrays[entry] = { n = 0 }
				shell.Vars[entry] = nil
			end
		end
	end

	return ok("")
end

--// Aliases, functions, commands //--

local function builtinAlias(shell, args, stdin)
	if #args == 0 then
		local names = {}
		for name in shell.Aliases do table.insert(names, name) end
		table.sort(names)
		local out = {}
		for _, name in names do
			table.insert(out, `alias {name}={shellQuote(shell.Aliases[name])}`)
		end
		return ok(table.concat(out, "\n"))
	end

	local printMode = false
	local i = 1
	if args[1] == "-p" then printMode = true; i = 2 end

	local out = {}
	for j = i, #args do
		local name, value = string.match(args[j], "^([^=]+)=(.*)$")
		if name then
			shell.Aliases[name] = value
		elseif printMode then
			if shell.Aliases[args[j]] then
				table.insert(out, `alias {args[j]}={shellQuote(shell.Aliases[args[j]])}`)
			end
		elseif shell.Aliases[args[j]] then
			table.insert(out, `alias {args[j]}={shellQuote(shell.Aliases[args[j]])}`)
		else
			return fail(`alias: {args[j]}: not found`, 1)
		end
	end

	return ok(table.concat(out, "\n"))
end

local function builtinUnalias(shell, args, stdin)
	if args[1] == "-a" then
		shell.Aliases = {}
		return ok("")
	end
	for _, name in args do
		if shell.Aliases[name] == nil then
			return fail(`unalias: {name}: not found`, 1)
		end
		shell.Aliases[name] = nil
	end
	return ok("")
end

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

local function typeKind(shell, name: string): string?
	if shell.Aliases[name] then return "alias" end
	if shell.Functions[name] then return "function" end
	if Builtins[name] then return "builtin" end
	if shell.Service:GetCommand(name) then return "command" end
	return nil
end

local function builtinType(shell, args, stdin)
	local tOnly = false
	local all = false
	local names = {}

	for _, arg in args do
		if arg == "-t" then tOnly = true
		elseif arg == "-a" then all = true
		elseif arg == "-p" or arg == "-P" then
			-- no PATH lookup
		elseif string.sub(arg, 1, 1) ~= "-" then
			table.insert(names, arg)
		end
	end

	local out = {}
	local code = 0

	for _, name in names do
		local kind = typeKind(shell, name)
		if not kind then
			code = 1
			if not tOnly then table.insert(out, `{name}: not found`) end
		elseif tOnly then
			table.insert(out, kind)
		else
			table.insert(out, describe(shell, name))
		end
	end

	return code, table.concat(out, "\n"), ""
end

local function builtinCommand(shell, args, stdin)
	local verbose = nil
	local i = 1

	while i <= #args do
		if args[i] == "-v" then verbose = "short"
		elseif args[i] == "-V" then verbose = "long"
		elseif args[i] == "-p" then
		elseif args[i] == "--" then i += 1; break
		elseif string.sub(args[i], 1, 1) == "-" then
			return fail(`command: {args[i]}: invalid option`, 2)
		else
			break
		end
		i += 1
	end

	if i > #args then return ok("") end

	if verbose then
		local out = {}
		local code = 0
		for j = i, #args do
			local kind = typeKind(shell, args[j])
			if not kind then
				code = 1
			elseif verbose == "short" then
				table.insert(out, args[j])
			else
				table.insert(out, describe(shell, args[j]))
			end
		end
		return code, table.concat(out, "\n"), ""
	end

	local words = {}
	for j = i, #args do table.insert(words, args[j]) end
	return shell:ExecuteCommand(words, stdin, { noAlias = true, noFunction = true })
end

local function builtinBuiltin(shell, args, stdin)
	if #args == 0 then return ok("") end
	local name = args[1]
	local builtin = Builtins[name]
	if not builtin then
		return fail(`builtin: {name}: not a shell builtin`, 1)
	end
	local rest = {}
	for i = 2, #args do table.insert(rest, args[i]) end
	return builtin.Run(shell, rest, stdin)
end

--// Control flow //--

local function builtinExit(shell, args, stdin)
	local code = tonumber(args[1]) or shell.Status
	code = math.floor(code) % 256
	shell.ExitRequested = code
	shell.Status = code
	return 0, "", ""
end

local function builtinReturn(shell, args, stdin)
	local code = tonumber(args[1]) or shell.Status
	signal("return", math.floor(code) % 256)
	return 0, "", ""
end

local function builtinBreak(shell, args, stdin)
	signal("break", tonumber(args[1]) or 1)
	return 0, "", ""
end

local function builtinContinue(shell, args, stdin)
	signal("continue", tonumber(args[1]) or 1)
	return 0, "", ""
end

local function builtinShift(shell, args, stdin)
	local count = tonumber(args[1]) or 1
	if count < 0 then return fail("shift: shift count out of range", 1) end
	if count > #shell.Positional then
		return fail("shift: shift count out of range", 1)
	end
	for _ = 1, count do
		table.remove(shell.Positional, 1)
	end
	return ok("")
end

--// eval / source / exec //--

local function builtinEval(shell, args, stdin)
	local line = table.concat(args, " ")
	local code, output, err = shell:RunString(line, stdin)
	return code, output, err
end

local function builtinSource(shell, args, stdin)
	if #args == 0 then
		return fail("source: filename argument required", 2)
	end

	local name = args[1]
	local script = nil

	if name == "/dev/stdin" or name == "-" then
		script = stdin
	else
		script = shell:GetVar(name)
	end

	if script == nil then
		-- Allow `source 'echo hi'` because there is no filesystem to read from.
		if string.find(name, "[%s;|&]") then
			script = name
		else
			return fail(`source: {name}: No such file or directory`, 1)
		end
	end

	local saved = shell.Positional
	local positional = {}
	for i = 2, #args do table.insert(positional, args[i]) end
	if #positional > 0 then
		shell.Positional = positional
	end

	local ok, code, output, err = pcall(shell.RunString, shell, script, stdin)

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

	return code, output, err
end

local function builtinExec(shell, args, stdin)
	if #args == 0 then return ok("") end
	local code, output, err = shell:ExecuteCommand(args, stdin)
	shell.Status = code
	shell.ExitRequested = code
	return code, output, err
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

local function builtinDate(shell, args, stdin)
	local utc = false
	local format = nil
	local dateString = nil
	local i = 1

	while i <= #args do
		local arg = args[i]
		if arg == "-u" or arg == "--utc" or arg == "--universal" then
			utc = true
		elseif arg == "-R" or arg == "--rfc-2822" then
			format = "%a, %d %b %Y %H:%M:%S %z"
		elseif arg == "-I" or arg == "--iso-8601" then
			format = "%Y-%m-%d"
		elseif string.sub(arg, 1, 1) == "+" then
			format = string.sub(arg, 2)
		elseif arg == "-d" or arg == "--date" then
			i += 1
			dateString = args[i]
		elseif arg == "-r" or arg == "--reference" then
			i += 1
			dateString = args[i]
		elseif arg == "--" then
			i += 1
			break
		else
			format = arg
		end
		i += 1
	end

	if format and format == "%s" then
		return ok(tostring(os.time()))
	end

	local stamp = os.time()
	if dateString then
		-- support @epoch and the common YYYY-MM-DD[ HH:MM[:SS]] form
		local epoch = string.match(dateString, "^@(%d+)$")
		if epoch then
			stamp = tonumber(epoch)
		else
			local y, m, d, hh, mm, ss = string.match(dateString, "^(%d%d%d%d)%-(%d%d)%-(%d%d)[T ]?(%d?%d?):?(%d?%d?):?(%d?%d?)$")
			if y then
				local dt = os.time({
					year = tonumber(y), month = tonumber(m), day = tonumber(d),
					hour = tonumber(hh) or 0, min = tonumber(mm) or 0, sec = tonumber(ss) or 0,
					isdst = false,
				})
				if dt then stamp = dt end
			end
		end
	end

	if not format then
		format = "%a %b %e %H:%M:%S %Z %Y"
	end

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

local function parseDuration(text: string): number?
	local total = 0
	local matched = false
	for number, suffix in string.gmatch(text, "(%d+%.?%d*)([smhd]?)") do
		local value = tonumber(number)
		if value then
			matched = true
			if suffix == "m" then value *= 60
			elseif suffix == "h" then value *= 3600
			elseif suffix == "d" then value *= 86400 end
			total += value
		end
	end
	if not matched then return nil end
	return total
end

local function builtinSleep(shell, args, stdin)
	if #args == 0 then
		return fail("sleep: missing operand", 2)
	end

	local total = 0
	for _, arg in args do
		local value = parseDuration(arg)
		if not value then
			return fail(`sleep: invalid time interval '{arg}'`, 1)
		end
		total += value
	end

	if total > 300 then total = 300 end
	if total > 0 then
		task.wait(total)
	end
	return ok("")
end

local function builtinSeq(shell, args, stdin)
	local separator = "\n"
	local equalWidth = false
	local format = nil
	local numbers = {}
	local i = 1

	while i <= #args do
		local arg = args[i]
		if arg == "-s" or arg == "--separator" then
			i += 1
			separator = args[i] or "\n"
		elseif string.sub(arg, 1, 2) == "-s" then
			separator = string.sub(arg, 3)
		elseif arg == "-w" or arg == "--equal-width" then
			equalWidth = true
		elseif arg == "-f" or arg == "--format" then
			i += 1
			format = args[i]
		elseif string.sub(arg, 1, 2) == "-f" then
			format = string.sub(arg, 3)
		elseif arg == "--" then
			i += 1
			while i <= #args do table.insert(numbers, args[i]); i += 1 end
			break
		else
			table.insert(numbers, arg)
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
		for _, value in values do width = math.max(width, #tostring(value)) end
	end

	for index, value in values do
		if format then
			local success, text = pcall(string.format, format, value)
			values[index] = if success then text else tostring(value)
		elseif equalWidth then
			values[index] = string.rep("0", math.max(0, width - #tostring(value))) .. tostring(value)
		else
			values[index] = tostring(value)
		end
	end

	return ok(table.concat(values, separator))
end

local function builtinYes(shell, args, stdin)
	local text = if #args > 0 then table.concat(args, " ") else "y"
	local out = {}
	local total = 0
	while total < 8192 do
		table.insert(out, text)
		total += #text + 1
	end
	return ok(table.concat(out, "\n"))
end

--// tee / xargs //--

local function builtinTee(shell, args, stdin)
	local targets = {}
	for _, arg in args do
		if arg ~= "-a" and arg ~= "--append" then
			table.insert(targets, arg)
		end
	end

	local errors = {}
	for _, target in targets do
		local success, err = shell:Redirect(stdin, target)
		if not success then table.insert(errors, err) end
	end

	local code = if #errors > 0 then 1 else 0
	return code, stdin, table.concat(errors, "\n")
end

local function splitNul(text: string): { string }
	local out = {}
	for piece in string.gmatch(text, "([^%z]*)%z") do
		table.insert(out, piece)
	end
	if #out == 0 then
		for piece in string.gmatch(text, "%S+") do table.insert(out, piece) end
	end
	return out
end

local function builtinXargs(shell, args, stdin)
	local nullDelimited = false
	local replace = nil
	local maxArgs = nil
	local noRun = false
	local trace = false
	local command = {}
	local i = 1

	while i <= #args do
		local arg = args[i]
		if arg == "-0" or arg == "--null" then nullDelimited = true
		elseif arg == "-r" or arg == "--no-run-if-empty" then noRun = true
		elseif arg == "-t" or arg == "--verbose" then trace = true
		elseif arg == "-n" or arg == "--max-args" then i += 1; maxArgs = tonumber(args[i])
		elseif string.sub(arg, 1, 2) == "-n" then maxArgs = tonumber(string.sub(arg, 3))
		elseif arg == "-I" or arg == "--replace" then i += 1; replace = args[i]
		elseif string.sub(arg, 1, 2) == "-I" then replace = string.sub(arg, 3)
		elseif arg == "-d" or arg == "--delimiter" then i += 1; nullDelimited = args[i] == "\0"
		elseif string.sub(arg, 1, 2) == "-d" then nullDelimited = string.sub(arg, 3) == "\0"
		elseif arg == "--" then
			i += 1
			while i <= #args do table.insert(command, args[i]); i += 1 end
			break
		else
			table.insert(command, arg)
		end
		i += 1
	end

	if #command == 0 then command = { "echo" } end

	local items = if nullDelimited then splitNul(stdin) else (function()
		local list = {}
		for piece in string.gmatch(stdin, "%S+") do table.insert(list, piece) end
		return list
	end)()

	if #items == 0 and noRun then
		return ok("")
	end

	local results = {}
	local errors = {}
	local finalCode = 0

	local function run(batch: { string })
		if replace then
			local words = {}
			for _, word in command do
				table.insert(words, string.gsub(word, replace, function() return batch[1] or "" end))
			end
			if trace then table.insert(results, table.concat(words, " ")) end
			local code, output, err = shell:ExecuteCommand(words, "")
			finalCode = code
			if output ~= "" then table.insert(results, output) end
			if err ~= "" then table.insert(errors, err) end
		else
			local words = table.clone(command)
			for _, item in batch do table.insert(words, item) end
			if trace then table.insert(results, table.concat(words, " ")) end
			local code, output, err = shell:ExecuteCommand(words, "")
			finalCode = code
			if output ~= "" then table.insert(results, output) end
			if err ~= "" then table.insert(errors, err) end
		end
	end

	if replace then
		for _, item in items do run({ item }) end
	elseif maxArgs and maxArgs > 0 then
		local batch = {}
		for _, item in items do
			table.insert(batch, item)
			if #batch >= maxArgs then
				run(batch)
				batch = {}
			end
		end
		if #batch > 0 then run(batch) end
	else
		run(items)
	end

	return finalCode, table.concat(results, "\n"), table.concat(errors, "\n")
end

--// jobs //--

local function builtinJobs(shell, args, stdin)
	local out = {}
	for _, job in shell.Jobs do
		local status = if job.Done then (if job.Code == 0 then "Done" else `Exit {job.Code}`) else "Running"
		table.insert(out, `[{job.Id}] {status}\t{job.Command}`)
	end
	return ok(table.concat(out, "\n"))
end

local function builtinWait(shell, args, stdin)
	local target = tonumber(args[1])
	for _, job in shell.Jobs do
		if target == nil or job.Id == target then
			while not job.Done do
				task.wait()
			end
			if target ~= nil then return job.Code, "", "" end
		end
	end
	return ok("")
end

local function builtinDisown(shell, args, stdin)
	for _, job in shell.Jobs do
		job.Disowned = true
	end
	return ok("")
end

local function findJob(shell, args)
	local target = tonumber(args[1]) or shell.LastBg
	for _, job in shell.Jobs do
		if job.Id == target and not job.Disowned then
			return job
		end
	end
	return nil
end

local function builtinFg(shell, args, stdin)
	local job = findJob(shell, args)
	if not job then
		return fail("fg: no such job", 1)
	end
	while not job.Done do
		task.wait()
	end
	return job.Code or 0, "", ""
end

local function builtinBg(shell, args, stdin)
	local job = findJob(shell, args)
	if not job then
		return fail("bg: no such job", 1)
	end
	if job.Done then
		return fail("bg: job has terminated", 1)
	end
	return ok(`[{job.Id}] {job.Command} &`)
end

--// history //--

local function builtinHistory(shell, args, stdin)
	if args[1] == "-c" then
		shell.History = {}
		return ok("")
	end

	if args[1] == "-d" then
		local index = tonumber(args[2])
		if index and shell.History[index] then
			table.remove(shell.History, index)
		end
		return ok("")
	end

	local count = tonumber(args[1]) or 20
	local start = math.max(1, #shell.History - count + 1)
	local out = {}
	for i = start, #shell.History do
		table.insert(out, `{i}  {shell.History[i]}`)
	end
	return ok(table.concat(out, "\n"))
end

--// read //--

local function splitReadFields(line: string, ifs: string): ({ string }, { number })
	if ifs == "" then
		return { line }, { 1 }
	end

	local whitespace = " \t\n"
	local fields = {}
	local starts = {}
	local i = 1
	local length = #line

	local function isIfs(c: string): boolean
		return string.find(ifs, c, 1, true) ~= nil
	end

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
			if isIfs(c) then break end
			table.insert(field, c)
			i += 1
		end
		table.insert(fields, table.concat(field))
		table.insert(starts, start)

		while i <= length and isIfs(string.sub(line, i, i)) do
			local c = string.sub(line, i, i)
			i += 1
			if not isIfsWhite(c) then break end
		end
	end

	return fields, starts
end

local function builtinRead(shell, args, stdin)
	local raw = false
	local arrayName = nil
	local delimiter = "\n"
	local names = {}
	local i = 1

	while i <= #args do
		local arg = args[i]
		if arg == "-r" then raw = true
		elseif arg == "-p" then i += 1
		elseif arg == "-d" then i += 1; delimiter = args[i] or "\n"
		elseif arg == "-a" then i += 1; arrayName = args[i]
		elseif arg == "-n" or arg == "-N" or arg == "-t" then i += 1
		elseif arg == "--" then i += 1; break
		elseif string.sub(arg, 1, 1) ~= "-" then break
		end
		i += 1
	end

	while i <= #args do table.insert(names, args[i]); i += 1 end
	if #names == 0 and not arrayName then names = { "REPLY" } end

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

local function builtinMapfile(shell, args, stdin)
	local name = "MAPFILE"
	local i = 1

	while i <= #args do
		local arg = args[i]
		if arg == "-t" then
			i += 1
		elseif arg == "-n" or arg == "-O" or arg == "-s" or arg == "-c" or arg == "-d" then
			i += 2
		elseif string.sub(arg, 1, 1) ~= "-" then
			name = arg
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
local function builtinEnv(shell, args, stdin)
	local savedVars = table.clone(shell.Vars)
	local savedExported = table.clone(shell.Exported)

	local function restore()
		shell.Vars = savedVars
		shell.Exported = savedExported
	end

	if #args == 0 then
		local names = {}
		for name in shell.Exported do table.insert(names, name) end
		table.sort(names)
		local out = {}
		for _, name in names do
			local value = shell:GetVar(name)
			if value ~= nil then table.insert(out, `{name}={value}`) end
		end
		return ok(table.concat(out, "\n"))
	end

	local i = 1
	while i <= #args do
		local name, value = string.match(args[i], "^([^=]+)=(.*)$")
		if name then
			shell:SetVar(name, value, true)
			i += 1
		elseif args[i] == "-i" or args[i] == "--ignore-environment" then
			shell.Vars = {}
			shell.Exported = {}
			i += 1
		elseif args[i] == "-u" or args[i] == "--unset" then
			i += 1
			shell.Vars[args[i]] = nil
			shell.Exported[args[i]] = nil
			i += 1
		else
			break
		end
	end

	if i > #args then
		local code, output, err = builtinEnv(shell, {}, stdin)
		restore()
		return code, output, err
	end

	local words = {}
	for j = i, #args do table.insert(words, args[j]) end
	local code, output, err = shell:ExecuteCommand(words, stdin)
	restore()
	return code, output, err
end

local function builtinPwd(shell, args, stdin)
	return ok(shell:GetVar("PWD") or "/")
end

local function builtinCd(shell, args, stdin)
	return fail("cd: there is no filesystem in this terminal", 1)
end

local function builtinLet(shell, args, stdin)
	if #args == 0 then return 1, "", "" end
	local value = 0
	local success, result = pcall(function()
		return shell:Arithmetic(table.concat(args, " "))
	end)
	if not success then return fail(tostring(result), 1) end
	value = result
	if value ~= 0 then
		return 0, "", ""
	end
	return 1, "", ""
end

local function builtinCat(shell, args, stdin)
	if #args > 0 then
		return fail(`cat: {args[1]}: No such file or directory`, 1)
	end
	return ok(stdin)
end

local function builtinBasename(shell, args, stdin)
	if #args == 0 then
		return fail("basename: missing operand", 2)
	end

	local path = args[1]
	path = string.gsub(path, "/+$", "")
	if path == "" then
		path = "/"
	end
	local name = string.match(path, "([^/]+)$") or path

	if args[2] and args[2] ~= "" and string.sub(name, -#args[2]) == args[2] and #name > #args[2] then
		name = string.sub(name, 1, #name - #args[2])
	end

	return ok(name)
end

local function builtinDirname(shell, args, stdin)
	if #args == 0 then
		return fail("dirname: missing operand", 2)
	end

	local path = string.gsub(args[1], "/+$", "")
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

		if c1 == "" or c2 == "" then break end
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

local function builtinBase64(shell, args, stdin)
	local decode = false
	local wrap = 76
	local i = 1

	while i <= #args do
		local arg = args[i]
		if arg == "-d" or arg == "--decode" then
			decode = true
		elseif arg == "-w" or arg == "--wrap" then
			i += 1
			wrap = tonumber(args[i]) or 76
		elseif string.sub(arg, 1, 2) == "-w" then
			wrap = tonumber(string.sub(arg, 3)) or 76
		elseif arg == "-i" or arg == "--ignore-garbage" then
			-- whitespace is already ignored on decode
		elseif arg == "--" then
			i += 1
			break
		else
			break
		end
		i += 1
	end

	if i <= #args then
		return fail(`base64: {args[i]}: No such file or directory`, 1)
	end

	if decode then
		local decoded, err = base64Decode(stdin)
		if not decoded then
			return fail(`base64: {err}`, 1)
		end
		return ok(decoded)
	end

	return ok(base64Encode(stdin, wrap))
end

local function builtinLocal(shell, args, stdin)
	if #shell.LocalFrames == 0 then
		return fail("local: can only be used in a function", 1)
	end

	for _, arg in args do
		if string.sub(arg, 1, 1) == "-" then
			-- -r, -x, -a, -i, -n are accepted but have no separate storage here
			continue
		end

		local name, value = string.match(arg, "^([^=]+)=(.*)$")
		if name then
			if not isIdentifier(name) then
				return fail(`local: '{name}': not a valid identifier`, 1)
			end
			shell:SetLocal(name, value)
		else
			if not isIdentifier(arg) then
				return fail(`local: '{arg}': not a valid identifier`, 1)
			end
			shell:SetLocal(arg, "")
		end
	end

	return ok("")
end

local function builtinReadonly(shell, args, stdin)
	shell.Readonly = shell.Readonly or {}
	for _, arg in args do
		local name, value = string.match(arg, "^([^=]+)=(.*)$")
		if name then
			shell:SetVar(name, value)
			shell.Readonly[name] = true
		elseif arg ~= "-p" and arg ~= "-f" then
			shell.Readonly[arg] = true
		end
	end
	return ok("")
end

local function builtinShopt(shell, args, stdin)
	if #args == 0 then
		return ok("dotglob\toff\nexpand_aliases\ton\nglobstar\toff\nnullglob\toff\n")
	end
	return ok("")
end

local function builtinHash(shell, args, stdin)
	return ok("")
end

local function builtinTrap(shell, args, stdin)
	if #args == 0 then
		local out = {}
		for sig, action in shell.Traps or {} do
			table.insert(out, `trap -- '{action}' {sig}`)
		end
		return ok(table.concat(out, "\n"))
	end

	local action = args[1]

	if action == "-l" then
		return ok("EXIT HUP INT QUIT ILL TRAP ABRT BUS FPE KILL USR1 SEGV USR2 PIPE ALRM TERM")
	end

	if action == "-p" then
		local out = {}
		local wanted = if args[2] then args[2] else nil
		for sig, value in shell.Traps or {} do
			if not wanted or sig == wanted or (wanted == "0" and sig == "EXIT") then
				table.insert(out, `trap -- '{value}' {sig}`)
			end
		end
		return ok(table.concat(out, "\n"))
	end

	shell.Traps = shell.Traps or {}

	for index = 2, #args do
		local signal = args[index]
		if signal == "0" then signal = "EXIT" end
		if action == "-" then
			shell.Traps[signal] = nil
		else
			shell.Traps[signal] = action
		end
	end

	return ok("")
end

local function builtinUmask(shell, args, stdin)
	return ok("0022")
end

local function builtinUlimit(shell, args, stdin)
	return ok("unlimited")
end

--// metadata //--

local function describeBuiltin(name, aliases, description, args)
	return {
		Name = name,
		Aliases = aliases or {},
		Description = description,
		Args = args or {},
		Permission = "Any",
		IsBuiltin = true,
	}
end

local definitions = {
	{
		Name = ":", Description = "Do nothing, successfully.", Run = function() return 0, "", "" end,
	},
	{
		Name = "true", Description = "Do nothing, successfully.", Run = function() return 0, "", "" end,
	},
	{
		Name = "false", Description = "Do nothing, unsuccessfully.", Run = function() return 1, "", "" end,
	},
	{
		Name = "echo", Aliases = {}, Description = "Write arguments to standard output.",
		Run = builtinEcho,
	},
	{
		Name = "printf", Description = "Format and print data.",
		Run = builtinPrintf,
	},
	{
		Name = "test", Aliases = {}, Description = "Evaluate a conditional expression.",
		Run = function(shell, args, stdin) return builtinTest(shell, args, stdin, false, false) end,
	},
	{
		Name = "[", Description = "Evaluate a conditional expression (closing ] required).",
		Run = function(shell, args, stdin) return builtinTest(shell, args, stdin, true, false) end,
	},
	{
		Name = "[[", Description = "Evaluate an extended conditional expression.",
		Run = function(shell, args, stdin) return builtinTest(shell, args, stdin, false, true) end,
	},
	{
		Name = "export", Description = "Mark variables for export to child commands.",
		Run = builtinExport,
	},
	{
		Name = "unset", Description = "Remove variables or functions.",
		Run = builtinUnset,
	},
	{
		Name = "set", Description = "Set shell options and positional parameters.",
		Run = builtinSet,
	},
	{
		Name = "declare", Aliases = { "typeset" }, Description = "Declare variables and functions.",
		Run = builtinDeclare,
	},
	{
		Name = "local", Description = "Create a function-local variable.",
		Run = builtinLocal,
	},
	{
		Name = "alias", Description = "Define or display aliases.",
		Run = builtinAlias,
	},
	{
		Name = "unalias", Description = "Remove aliases.",
		Run = builtinUnalias,
	},
	{
		Name = "type", Description = "Describe how a name would be interpreted.",
		Run = builtinType,
	},
	{
		Name = "which", Description = "Locate a command.",
		Run = function(shell, args, stdin)
			local out = {}
			local code = 0
			for _, name in args do
				local kind = typeKind(shell, name)
				if kind then table.insert(out, name) else code = 1 end
			end
			return code, table.concat(out, "\n"), ""
		end,
	},
	{
		Name = "command", Description = "Run a command, bypassing functions and aliases.",
		Run = builtinCommand,
	},
	{
		Name = "builtin", Description = "Run a shell builtin.",
		Run = builtinBuiltin,
	},
	{
		Name = "exit", Description = "Exit the shell.",
		Run = builtinExit,
	},
	{
		Name = "return", Description = "Return from a shell function.",
		Run = builtinReturn,
	},
	{
		Name = "break", Description = "Exit a loop.",
		Run = builtinBreak,
	},
	{
		Name = "continue", Description = "Resume the next loop iteration.",
		Run = builtinContinue,
	},
	{
		Name = "shift", Description = "Shift positional parameters.",
		Run = builtinShift,
	},
	{
		Name = "eval", Description = "Evaluate arguments as a shell command.",
		Run = builtinEval,
	},
	{
		Name = "source", Aliases = { "." }, Description = "Evaluate a script stored in a variable.",
		Run = builtinSource,
	},
	{
		Name = "exec", Description = "Replace the shell with a command.",
		Run = builtinExec,
	},
	{
		Name = "date", Description = "Display the current date and time.",
		Run = builtinDate,
	},
	{
		Name = "sleep", Description = "Delay for a specified amount of time.",
		Run = builtinSleep,
	},
	{
		Name = "seq", Description = "Print a sequence of numbers.",
		Run = builtinSeq,
	},
	{
		Name = "yes", Description = "Print a string repeatedly.",
		Run = builtinYes,
	},
	{
		Name = "tee", Description = "Copy standard input to a player terminal and to standard output.",
		Run = builtinTee,
	},
	{
		Name = "xargs", Description = "Build and run commands from standard input.",
		Run = builtinXargs,
	},
	{
		Name = "jobs", Description = "List background jobs.",
		Run = builtinJobs,
	},
	{
		Name = "fg", Description = "Wait for a background job.",
		Run = builtinFg,
	},
	{
		Name = "bg", Description = "Show a background job.",
		Run = builtinBg,
	},
	{
		Name = "wait", Description = "Wait for background jobs.",
		Run = builtinWait,
	},
	{
		Name = "disown", Description = "Forget background jobs.",
		Run = builtinDisown,
	},
	{
		Name = "history", Aliases = { "hist" }, Description = "Display the command history.",
		Run = builtinHistory,
	},
	{
		Name = "cat", Description = "Concatenate stdin (there is no filesystem).",
		Run = builtinCat,
	},
	{
		Name = "basename", Description = "Strip directory and suffix from a path string.",
		Run = builtinBasename,
	},
	{
		Name = "dirname", Description = "Strip the last component from a path string.",
		Run = builtinDirname,
	},
	{
		Name = "base64", Description = "Base64 encode or decode stdin.",
		Run = builtinBase64,
	},
	{
		Name = "read", Description = "Read a line from standard input into variables.",
		Run = builtinRead,
	},
	{
		Name = "mapfile", Aliases = { "readarray" }, Description = "Read lines from standard input into an array.",
		Run = builtinMapfile,
	},
	{
		Name = "env", Description = "Display the environment or run a command in it.",
		Run = builtinEnv,
	},
	{
		Name = "printenv", Description = "Print environment variables.",
		Run = function(shell, args, stdin)
			if #args == 0 then return builtinEnv(shell, {}, stdin) end
			local out = {}
			local code = 0
			for _, name in args do
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
		Name = "pwd", Description = "Print the current directory.",
		Run = builtinPwd,
	},
	{
		Name = "cd", Description = "Change directory (unavailable: no filesystem).",
		Run = builtinCd,
	},
	{
		Name = "let", Description = "Evaluate arithmetic expressions.",
		Run = builtinLet,
	},
	{
		Name = "readonly", Aliases = { "declare -r" }, Description = "Mark variables as read-only.",
		Run = builtinReadonly,
	},
	{
		Name = "shopt", Description = "Toggle shell options.",
		Run = builtinShopt,
	},
	{
		Name = "hash", Description = "Remember command locations.",
		Run = builtinHash,
	},
	{
		Name = "trap", Description = "Set signal handlers.",
		Run = builtinTrap,
	},
	{
		Name = "umask", Description = "Display or set the file mode mask.",
		Run = builtinUmask,
	},
	{
		Name = "ulimit", Description = "Display resource limits.",
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

-- Aliases registered as their own entries ("." for source) must resolve to the same builtin.
Builtins["."] = Builtins["source"]

return Builtins
