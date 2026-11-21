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
	One shell instance per player (plus one for the server).

	The shell owns variables, aliases, functions, positional parameters, options,
	the exit status and the job list. It evaluates the AST produced by Parser and
	runs either a builtin (Classes/Shell/Builtins) or a registered Roblox command.

	There is no filesystem on purpose: `>` still means "print into a player's
	terminal", not "write a file".
]=]

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

local Lexer = require(script.Parent.Parent.Parser.Lexer)
local Parser = require(script.Parent.Parent.Parser.Parser)
local Expander = require(script.Parent.Parent.Parser.Expander)
local Arithmetic = require(script.Parent.Parent.Classes.Arithmetic)
local Glob = require(script.Parent.Parent.Classes.Glob)
local CommandContext = require(script.Parent.Parent.Classes.CommandContext)
local Builtins = require(script.Builtins)

local MAX_STEPS = 20000
local MAX_OUTPUT = 16384
local MAX_DEPTH = 32

local Shell = {}
Shell.__index = Shell

--[=[
	Joins two output strings, adding a newline only when needed.

	@param a The first value.
	@param b The second value.
	@return The resulting text.
]=]
local function joinOutput(a: string?, b: string?): string
	if a == nil or a == "" then
		return b or ""
	end
	if b == nil or b == "" then
		return a
	end
	if string.sub(a, -1) == "\n" then
		return a .. b
	end
	return a .. "\n" .. b
end

--[=[
	Joins a list of output strings.

	@param parts The parts to combine.
	@return The resulting text.
]=]
local function joinMany(parts: { string }): string
	local out = ""
	for _, part in parts do
		out = joinOutput(out, part)
	end
	return out
end

--[=[
	Rethrows a shell control signal while preserving its output.

	@param errObj The shell control signal that was raised.
	@param output The output produced before the signal.
	@param errorValue The error value to inspect.
]=]
local function rethrow(errObj, output: string?, errorValue: string?)
	if type(errObj) == "table" and errObj.__shellControl then
		errObj.Output = joinOutput(output, errObj.Output)
		errObj.Errors = joinOutput(errorValue, errObj.Errors)
	end
	error(errObj, 0)
end

--[=[
	Truncates captured output to the shell limit.

	@param text The text to inspect.
	@return The resulting text.
]=]
local function cap(text: string?): string
	text = text or ""
	if #text > MAX_OUTPUT then
		return string.sub(text, 1, MAX_OUTPUT) .. "\n[output truncated]"
	end
	return text
end

--[=[
	Returns the plain text of a word token.

	@param token The token to inspect.
	@return The resulting text, or nil.
]=]
local function tokenText(token): string?
	if not token or token.Type ~= "word" then
		return nil
	end
	local parts = {}
	for _, part in token.Parts or {} do
		table.insert(parts, part.Text)
	end
	return table.concat(parts)
end

--[=[
	Returns the `read` command of a `while read` condition, if any.

	@param node The syntax tree node to evaluate.
	@return The result, or nil.
]=]
local function readCondition(node): any?
	if not node then
		return nil
	end

	local command = node
	if node.type == "Pipeline" then
		command = node.Commands[#node.Commands]
	end

	if not command or command.type ~= "Simple" then
		return nil
	end

	for _, token in command.Words do
		return if tokenText(token) == "read" then command else nil
	end

	return nil
end

--[=[
	Splits text into lines, keeping the final unterminated line.

	@param text The text to inspect.
	@return The resulting list.
]=]
local function splitLines(text: string): { string }
	local lines = {}
	for line in string.gmatch(text, "([^\n]*)\n") do
		table.insert(lines, line)
	end
	local rest = string.match(text, "([^\n]*)$")
	if rest ~= "" then
		table.insert(lines, rest)
	end
	return lines
end

--[=[
	Creates a shell for one player or for the server.

	@param service The terminal service.
	@param executor The player running the command.
	@return The new shell.
]=]
function Shell.new(service, executor)
	local self = setmetatable({}, Shell)

	self.Service = service
	self.Executor = executor
	self.Name = "bash"
	self.Pid = math.random(1000, 99999)
	self.Status = 0
	self.LastBg = nil
	self.LastArg = ""
	self.LastSubStatus = 0
	self.PipeStatuses = {}

	self.Vars = {}
	self.Arrays = {}
	self.Exported = {}
	self.Aliases = {}
	self.Functions = {}
	self.Readonly = {}
	self.Traps = {}
	self.Positional = {}
	self.History = {}
	self.Jobs = {}
	self.JobSeq = 0
	self.LocalFrames = {}
	self.ExitRequested = nil

	self.Options = {
		pipefail = false,
		errexit = false,
		nounset = false,
		xtrace = false,
		noglob = false,
		noclobber = false,
		monitor = false,
		history = true,
		interactive = true,
		emacs = true,
		allexport = false,
	}

	self.Steps = 0
	self.MaxSteps = MAX_STEPS
	self.SubDepth = 0
	self.FuncDepth = 0
	self.LoopDepth = 0
	self.ConditionDepth = 0
	self.NoErrexit = 0
	self.FuncStack = {}
	self.StartTime = os.clock()
	self.StartEpoch = os.time()

	self.Vars.HOME = "/"
	self.Vars.PWD = "/"
	self.Vars.OLDPWD = "/"
	self.Vars.PATH = "/usr/local/bin:/usr/bin:/bin"
	self.Vars.IFS = " \t\n"
	self.Vars.PS1 = "\\u@\\h:\\w\\$ "
	self.Vars.PS2 = "> "
	self.Vars.PS4 = "+ "
	self.Vars.USER = executor and executor.Name or "server"
	self.Vars.LOGNAME = self.Vars.USER
	self.Vars.SHELL = "/bin/bash"
	self.Vars.HOSTNAME = "roblox"
	self.Vars.TERM = "dumb"
	self.Vars.SHLVL = "1"
	self.Vars.BASH_VERSION = "5.2.0(1)-release"
	self.Vars.BASH = "/bin/bash"
	self.Vars.OSTYPE = "roblox"
	self.Vars.HOSTTYPE = "luau"
	self.Vars.MACHTYPE = "luau"
	self.Vars.COLUMNS = "80"
	self.Vars.LINES = "24"
	self.Vars.HISTSIZE = "500"
	self.Vars.HISTFILESIZE = "500"
	self.Vars.LANG = "C"
	self.Vars.LC_ALL = "C"

	for _, name in
		{
			"HOME",
			"PWD",
			"OLDPWD",
			"PATH",
			"USER",
			"LOGNAME",
			"SHELL",
			"HOSTNAME",
			"TERM",
			"SHLVL",
			"LANG",
			"LC_ALL",
		}
	do
		self.Exported[name] = true
	end

	return self
end

--[=[
	Creates a copy of the shell for command substitution.

	@return The new shell.
]=]
function Shell:Clone()
	local self2 = setmetatable({}, Shell)
	for key, value in self do
		if key == "Jobs" then
			self2.Jobs = {}
		elseif
			key == "Vars"
			or key == "Exported"
			or key == "Aliases"
			or key == "Functions"
			or key == "Readonly"
			or key == "Traps"
			or key == "Options"
			or key == "History"
			or key == "Positional"
			or key == "FuncStack"
			or key == "PipeStatuses"
			or key == "LocalFrames"
		then
			self2[key] = table.clone(value)
		elseif key == "Arrays" then
			local arrays = {}
			for name, array in value do
				local copy = { n = array.n or 0 }
				for index, item in array do
					copy[index] = item
				end
				arrays[name] = copy
			end
			self2.Arrays = arrays
		else
			self2[key] = value
		end
	end
	self2.SubDepth = self.SubDepth + 1
	self2.Steps = self.Steps
	self2.MaxSteps = self.MaxSteps
	self2.ExitRequested = nil
	return self2
end

--// State //--

--[=[
	Reads a variable, checking local frames first.

	@param name The name to look up.
	@return The resulting text, or nil.
]=]
function Shell:GetVar(name: string): string?
	for index = #self.LocalFrames, 1, -1 do
		local frame = self.LocalFrames[index]
		if frame[name] ~= nil then
			return frame[name]
		end
	end

	local value = self.Vars[name]
	if value ~= nil then
		return value
	end

	if name == "RANDOM" then
		return tostring(math.random(0, 32767))
	elseif name == "SECONDS" then
		return tostring(math.max(0, os.time() - (self.StartEpoch or os.time())))
	elseif name == "LINENO" then
		return "1"
	elseif name == "EPOCHSECONDS" then
		return tostring(os.time())
	elseif name == "EPOCHREALTIME" then
		return string.format("%.6f", os.clock())
	elseif name == "BASHPID" or name == "PPID" then
		return tostring(self.Pid)
	elseif name == "UID" or name == "EUID" then
		return tostring(self.Executor and self.Executor.UserId or 0)
	elseif name == "BASH_SUBSHELL" then
		return tostring(self.SubDepth)
	elseif name == "FUNCNAME" then
		return self.FuncStack[#self.FuncStack] or ""
	elseif name == "PIPESTATUS" then
		return table.concat(self.PipeStatuses, " ")
	end

	return nil
end

--[=[
	Assigns a variable and marks it exported when requested.

	@param name The name to look up.
	@param value The value to convert.
	@param exported Whether to print only exported variables.
]=]
function Shell:SetVar(name: string, value: any, exported: boolean?)
	if self.Readonly[name] then
		error(`${name}: readonly variable`, 0)
	end

	for index = #self.LocalFrames, 1, -1 do
		local frame = self.LocalFrames[index]
		if frame[name] ~= nil then
			if value == nil then
				frame[name] = nil
			else
				frame[name] = tostring(value)
			end
			return
		end
	end

	if value == nil then
		self.Vars[name] = nil
		return
	end

	self.Vars[name] = tostring(value)
	if exported or (self.Options and self.Options.allexport) then
		self.Exported[name] = true
	end
end

--[=[
	Declares a variable in the innermost function frame.

	@param name The name to look up.
	@param value The value to convert.
]=]
function Shell:SetLocal(name: string, value: any)
	local frame = self.LocalFrames[#self.LocalFrames]
	if not frame then
		error("local: can only be used in a function", 0)
	end
	if self.Readonly[name] then
		error(`${name}: readonly variable`, 0)
	end
	frame[name] = if value == nil then "" else tostring(value)
end

--[=[
	Returns the current positional parameters.

	@return The resulting list.
]=]
function Shell:GetPositional(): { string }
	return self.Positional
end

--[=[
	Formats the active shell options as `set` flags.

	@return The resulting text.
]=]
function Shell:OptionFlags(): string
	local flags = {}
	if self.Options.errexit then
		table.insert(flags, "e")
	end
	if self.Options.nounset then
		table.insert(flags, "u")
	end
	if self.Options.xtrace then
		table.insert(flags, "x")
	end
	if self.Options.noglob then
		table.insert(flags, "f")
	end
	if self.Options.noclobber then
		table.insert(flags, "C")
	end
	if self.Options.monitor then
		table.insert(flags, "m")
	end
	if self.Options.history then
		table.insert(flags, "h")
	end
	return "hB" .. table.concat(flags)
end

--[=[
	Counts an evaluation step and enforces the execution limit.
]=]
function Shell:Step()
	self.Steps += 1
	if self.Steps > self.MaxSteps then
		error("shell: execution limit exceeded", 0)
	end
end

--// Expansion callbacks //--

--[=[
	Expands a string without word splitting.

	@param text The text to inspect.
	@return The resulting text.
]=]
function Shell:ExpandInline(text: string): string
	return Expander.expandStringSingle(text, self)
end

--[=[
	Evaluates an arithmetic expression.

	@param expression The expression to evaluate.
	@return The resulting number.
]=]
function Shell:Arithmetic(expression: string): number
	local success, result = pcall(Arithmetic.eval, expression, self)
	if not success then
		error(tostring(result), 0)
	end
	return result
end

--[=[
	Runs a command in a child shell and captures its output.

	@param text The text to inspect.
	@return The resulting text.
]=]
function Shell:CommandSubstitute(text: string): string
	if self.SubDepth >= MAX_DEPTH then
		error("command substitution nested too deeply", 0)
	end

	local sub = self:Clone()
	sub.SubDepth = self.SubDepth + 1

	local ok, code, output, errorValue = pcall(sub.RunString, sub, text, "")
	self.Steps = math.max(self.Steps, sub.Steps)

	if not ok then
		if type(code) == "table" and code.__shellControl then
			error(code, 0)
		end
		error(tostring(code), 0)
	end

	self.LastSubStatus = code or 0

	if errorValue and errorValue ~= "" then
		self.Service:PrintTo(self.Executor, errorValue)
	end

	return (string.gsub(output or "", "\n+$", ""))
end

--// Output redirection //--

--[=[
	Collects the players named by a redirection target.

	@param target The target of the operation.
	@return The resulting list.
]=]
local function collectPlayers(target: any): { Player }
	local players = {}

	--[=[
		Adds a value to the player list when it is a Player instance.

		@param value The value to convert.
	]=]
	local function add(value)
		if typeof(value) == "Instance" and value:IsA("Player") then
			table.insert(players, value)
		end
	end

	if type(target) == "table" then
		if target.__isMultiValue then
			for _, value in target.Values do
				add(value)
			end
		else
			for _, value in target do
				add(value)
			end
		end
	else
		add(target)
	end

	return players
end

--[=[
	Sends text to a player's terminal or to `/dev/null`.

	@param text The text to inspect.
	@param target The target of the operation.
	@return The exit status, standard output and standard error.
]=]
function Shell:Redirect(text: string, target: string): (boolean, string?)
	if target == "/dev/null" or text == "" then
		return true, nil
	end

	local list = {}

	if target == "all" or target == "*" then
		for _, player in Players:GetPlayers() do
			table.insert(list, player)
		end
	else
		local playerType = self.Service:GetType("Player")
		if playerType then
			local valid = playerType.Validate(target, self.Executor, self.Service)
			if valid then
				local transformed = playerType.Transform(target, self.Executor, self.Service)
				list = collectPlayers(transformed)
			end
		end

		if #list == 0 then
			local player = Players:FindFirstChild(target)
			if player and player:IsA("Player") then
				table.insert(list, player)
			end
		end
	end

	if #list == 0 then
		return false, `redirect: {target}: no such player`
	end

	local others = false
	for _, player in list do
		if player ~= self.Executor then
			others = true
			break
		end
	end

	if others and self.Executor then
		local auth = self.Service.AuthorizationService
		local required = self.Service.RedirectPermission or "Moderator"
		if not auth or auth:HasPermissionAsync(self.Executor, required) ~= true then
			return false, "redirect: permission denied"
		end
	end

	local payload = text
	if others and self.Executor then
		local success, filtered = pcall(function()
			return TextService
				:FilterStringAsync(text, self.Executor.UserId, Enum.TextFilterContext.PublicChat)
				:GetNonChatStringForBroadcastAsync()
		end)
		if not success or filtered == nil then
			return false, "redirect: the text filter did not answer, nothing was sent"
		end
		payload = filtered
	end

	local network = self.Service.Network
	for _, player in list do
		if network then
			network:Fire(player, "RedirectPrint", payload)
		else
			self.Service:PrintTo(player, payload)
		end
	end

	return true, nil
end

--[=[
	Expands a here-document body.

	@param body The here-document body.
	@param shell The shell instance.
	@return The resulting text.
]=]
local function expandHereDoc(body: string, shell): string
	local parts = {}
	local buffer = {}

	--[=[
		Flushes the pending here-document text into the parts list.
	]=]
	local function flush()
		if #buffer > 0 then
			table.insert(parts, { Text = table.concat(buffer), Quote = 2 })
			buffer = {}
		end
	end

	local i = 1
	local length = #body
	while i <= length do
		local c = string.sub(body, i, i)
		if c == "\\" then
			local n = string.sub(body, i + 1, i + 1)
			if n == "\n" then
				i += 2
			elseif n == "\\" or n == "$" or n == "`" then
				flush()
				table.insert(parts, { Text = n, Quote = 1 })
				i += 2
			else
				table.insert(buffer, c)
				i += 1
			end
		else
			table.insert(buffer, c)
			i += 1
		end
	end

	flush()
	if #parts == 0 then
		parts = { { Text = "", Quote = 2 } }
	end

	return Expander.expandWordSingle({ Type = "word", Parts = parts, Quoted = true }, shell)
end

--[=[
	Applies a command's redirections and returns its input.

	@param redirects The redirections to apply.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
function Shell:ApplyRedirects(redirects, stdin): (string, any)
	local input = stdin
	local outTarget = nil
	local errTarget = nil
	local mergeErr = false
	local outToErr = false

	for _, redirect in redirects or {} do
		local op = redirect.Op
		local fd = redirect.Fd or 1

		if op == "<<<" then
			input = Expander.expandWordSingle(redirect.Target, self) .. "\n"
		elseif op == ">" or op == ">|" or op == ">>" then
			local target = Expander.expandWordSingle(redirect.Target, self)
			if target == "" then
				return input, "ambiguous redirect"
			end
			if fd == 2 then
				errTarget = target
			else
				outTarget = target
			end
		elseif op == "&>" or op == "&>>" then
			local target = Expander.expandWordSingle(redirect.Target, self)
			if target == "" then
				return input, "ambiguous redirect"
			end
			outTarget = target
			mergeErr = true
		elseif op == ">&" then
			local target = Expander.expandWordSingle(redirect.Target, self)
			if fd == 2 and target == "1" then
				mergeErr = true
			elseif fd == 1 and target == "2" then
				outToErr = true
			elseif fd == 1 and target == "1" then
			elseif fd == 2 and target == "2" then
			else
				return input, `{op}{target}: bad file descriptor`
			end
		elseif op == "<&" then
			return input, "input redirection from a file descriptor is not supported"
		elseif op == "<<" or op == "<<-" then
			local doc = redirect.HereDoc
			if not doc then
				return input, "here-document has no body"
			end
			local body = doc.Body or ""
			if doc.Expand then
				body = expandHereDoc(body, self)
			end
			input = body
		elseif op == "<" or op == "<>" then
			local target = Expander.expandWordSingle(redirect.Target, self)
			if target == "/dev/null" then
				input = ""
			else
				return input, "there is no filesystem: input redirection is not supported"
			end
		end
	end

	return input, { Out = outTarget, Err = errTarget, MergeErr = mergeErr, OutToErr = outToErr }
end

--// Commands //--

--[=[
	Splits an alias value into words.

	@param value The value to convert.
	@return The resulting list.
]=]
local function aliasWords(value: string): { string }
	local words = {}
	for _, token in Lexer.lex(value) do
		if token.Type == "word" then
			local text = {}
			for _, part in token.Parts or {} do
				table.insert(text, part.Text)
			end
			table.insert(words, table.concat(text))
		end
	end
	return words
end

--[=[
	Runs a shell function with its own positional parameters.

	@param name The name to look up.
	@param arguments The command arguments.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
function Shell:RunFunction(
	name: string,
	arguments: { string },
	stdin: string
): (number, string, string)
	local body = self.Functions[name]
	if not body then
		return 127, "", `{name}: command not found`
	end

	if self.FuncDepth >= MAX_DEPTH then
		error("shell: maximum function nesting level exceeded", 0)
	end

	local savedPositional = self.Positional
	self.Positional = table.clone(arguments)
	self.FuncDepth += 1
	table.insert(self.FuncStack, name)
	table.insert(self.LocalFrames, {})

	local ok, a, b, c = pcall(self.RunNode, self, body, stdin)

	table.remove(self.LocalFrames)
	self.FuncDepth -= 1
	table.remove(self.FuncStack)
	self.Positional = savedPositional

	if not ok then
		if type(a) == "table" and a.__shellControl then
			if a.Kind == "return" then
				self.Status = a.Value
				return a.Value, a.Output or "", a.Errors or ""
			end
			error(a, 0)
		end
		error(a, 0)
	end

	self.Status = if self.ExitRequested then self.ExitRequested else (a or 0)
	return a or 0, b or "", c or ""
end

--[=[
	Resolves and runs one simple command.

	@param words The command words.
	@param stdin The piped standard input.
	@param flags The formatting flags.
	@return The exit status, standard output and standard error.
]=]
function Shell:ExecuteCommand(
	words: { string },
	stdin: string,
	flags: any?
): (number, string, string)
	if #words == 0 then
		return 0, "", ""
	end

	flags = flags or {}
	local name = words[1]

	if not flags.noAlias then
		local seen = {}
		while true do
			local value = self.Aliases[name]
			if not value or seen[name] then
				break
			end
			seen[name] = true

			local replacement = aliasWords(value)
			if #replacement == 0 then
				break
			end

			local nextWords = {}
			for _, word in replacement do
				table.insert(nextWords, word)
			end
			for index = 2, #words do
				table.insert(nextWords, words[index])
			end
			words = nextWords
			name = words[1]
		end
	end

	local rest = {}
	for index = 2, #words do
		table.insert(rest, words[index])
	end

	if not flags.noFunction and self.Functions[name] then
		return self:RunFunction(name, rest, stdin)
	end

	local builtin = Builtins[name]
	if builtin then
		local ok, a, b, c = pcall(builtin.Run, self, rest, stdin)
		if not ok then
			if type(a) == "table" and a.__shellControl then
				error(a, 0)
			end
			return 1, "", `{name}: {tostring(a)}`
		end
		local code = a or 0
		if self.ExitRequested then
			self.Status = self.ExitRequested
		else
			self.Status = code
		end
		self.LastArg = rest[#rest] or name
		return code, b or "", c or ""
	end

	local command = self.Service:GetCommand(name)
	if command then
		local context = CommandContext.new(self.Executor, rest, stdin, self.Service, self)
		local ok, errorValue = pcall(function()
			command:Execute(context, rest, self.Service)
		end)
		if not ok then
			if type(errorValue) == "table" and errorValue.__shellControl then
				error(errorValue, 0)
			end
			return 1, "", `{name}: {tostring(errorValue)}`
		end

		self.Status = context.Code
		self.LastArg = rest[#rest] or name
		return context.Code, cap(context.Output), cap(context.ErrorMsg)
	end

	return 127, "", `{name}: command not found`
end

--// Loops //--

--[=[
	Runs a loop body and normalises control signals.

	@param node The syntax tree node to evaluate.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
function Shell:RunLoopBody(node, stdin)
	local ok, a, b, c = pcall(self.RunNode, self, node, stdin)
	if ok then
		return a or 0, b or "", c or "", nil
	end

	if type(a) == "table" and a.__shellControl then
		if a.Kind == "break" or a.Kind == "continue" then
			return 0, a.Output or "", a.Errors or "", a
		end
		error(a, 0)
	end

	error(a, 0)
end

--// AST //--

--[=[
	Runs a simple command, applying temporary assignments.

	@param node The syntax tree node to evaluate.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
function Shell:RunSimple(node, stdin)
	local saved = {}
	self.LastSubStatus = 0

	--[=[
		Restores variables saved before a simple command.
	]=]
	local function restoreAssignments()
		for name, previous in saved do
			if previous.Present then
				self.Vars[name] = previous.Value
			else
				self.Vars[name] = nil
			end
			self.Arrays[name] = previous.Array
			if previous.Exported then
				self.Exported[name] = true
			else
				self.Exported[name] = nil
			end
		end
	end

	local input, redirectInfo = self:ApplyRedirects(node.Redirects, stdin)

	local words = {}
	local wordsOk, wordsError = pcall(function()
		for _, token in node.Words do
			for _, field in Expander.expandWord(token, self) do
				table.insert(words, field)
			end
		end
	end)

	if not wordsOk then
		self.ExitRequested = 1
		return 1, "", tostring(wordsError)
	end

	local prefix = #node.Words > 0
	local assignmentsOk, assignmentError = pcall(function()
		for _, assignment in node.Assignments do
			saved[assignment.Name] = {
				Present = self.Vars[assignment.Name] ~= nil,
				Value = self.Vars[assignment.Name],
				Exported = self.Exported[assignment.Name],
				Array = self.Arrays[assignment.Name],
			}

			if assignment.Array then
				if self.Readonly[assignment.Name] then
					error(`${assignment.Name}: readonly variable`, 0)
				end

				local values = {}
				for _, token in assignment.Array do
					for _, field in Expander.expandWord(token, self) do
						table.insert(values, field)
					end
				end

				local array = if assignment.Append and self.Arrays[assignment.Name]
					then self.Arrays[assignment.Name]
					else { n = 0 }

				local start = array.n or 0
				for index, value in values do
					array[start + index - 1] = value
				end
				array.n = start + #values

				self.Arrays[assignment.Name] = array
				self.Vars[assignment.Name] = nil
			else
				local value = Expander.expandWordSingle(assignment.Value, self)
				if assignment.Append then
					value = (self:GetVar(assignment.Name) or "") .. value
				end
				self:SetVar(assignment.Name, value, prefix)
				self.Arrays[assignment.Name] = nil
			end
		end
	end)

	if not assignmentsOk then
		restoreAssignments()
		return 1, "", tostring(assignmentError)
	end

	local code, output, errorValue

	if #words == 0 then
		code, output, errorValue = self.LastSubStatus, "", ""
	else
		code, output, errorValue = self:ExecuteCommand(words, input or "")

		if self.Options.xtrace then
			errorValue = joinOutput(`+ {table.concat(words, " ")}`, errorValue)
		end

		restoreAssignments()
	end

	if type(redirectInfo) == "table" then
		if redirectInfo.OutToErr then
			errorValue = joinOutput(output, errorValue)
			output = ""
		end

		if redirectInfo.MergeErr then
			output = joinOutput(output, errorValue)
			errorValue = ""
		end

		if redirectInfo.Out then
			local success, message = self:Redirect(output, redirectInfo.Out)
			if not success then
				errorValue = joinOutput(errorValue, message)
				code = 1
			end
			output = ""
		end

		if redirectInfo.Err then
			local success, message = self:Redirect(errorValue, redirectInfo.Err)
			if not success then
				errorValue = joinOutput(errorValue, message)
				code = 1
			end
			errorValue = ""
		end
	elseif type(redirectInfo) == "string" then
		return 1, "", redirectInfo
	end

	self.Status = code
	if self.ExitRequested then
		self.Status = self.ExitRequested
	elseif
		self.Options.errexit
		and code ~= 0
		and self.ConditionDepth == 0
		and self.NoErrexit == 0
	then
		self.ExitRequested = code
	end
	return code, output, errorValue
end

--[=[
	Runs a pipeline and connects each stage's output to the next.

	@param node The syntax tree node to evaluate.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
function Shell:RunPipeline(node, stdin)
	local started = os.clock()
	local input = stdin
	local errors = {}
	local statuses = {}

	for index, command in node.Commands do
		local ok, code, output, errorValue = pcall(self.RunNode, self, command, input)
		if not ok then
			rethrow(code, nil, joinMany(errors))
		end
		statuses[index] = code

		if node.PipeErr[index] then
			input = joinOutput(output, errorValue)
		else
			input = output or ""
			if errorValue and errorValue ~= "" then
				table.insert(errors, errorValue)
			end
		end

		if self.ExitRequested then
			break
		end
	end

	local code = statuses[#statuses] or 0

	if self.Options.pipefail then
		code = 0
		for _, status in statuses do
			if status ~= 0 then
				code = status
			end
		end
	end

	if node.Negate then
		code = if code == 0 then 1 else 0
	end

	self.PipeStatuses = statuses
	local pipeArray = { n = #statuses }
	for index, status in statuses do
		pipeArray[index - 1] = tostring(status)
	end
	self.Arrays.PIPESTATUS = pipeArray
	self.Status = if self.ExitRequested then self.ExitRequested else code

	local elapsed = os.clock() - started
	local errorValue = joinMany(errors)

	if node.Time then
		local formatted =
			string.format("real\t0m%.3fs\nuser\t0m%.3fs\nsys\t0m0.000s", elapsed, elapsed)
		errorValue = joinOutput(errorValue, formatted)
	end

	if
		self.Options.errexit
		and code ~= 0
		and self.ConditionDepth == 0
		and self.NoErrexit == 0
		and not self.ExitRequested
	then
		self.ExitRequested = code
	end

	return code, input or "", errorValue
end

--[=[
	Runs `&&` and `||` lists.

	@param node The syntax tree node to evaluate.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
function Shell:RunAndOr(node, stdin)
	self.NoErrexit += 1
	local ok1, c1, o1, e1 = pcall(self.RunNode, self, node.Left, stdin)
	self.NoErrexit -= 1
	if not ok1 then
		rethrow(c1, nil, nil)
	end

	if self.ExitRequested then
		return c1, o1, e1
	end

	local runRight = (node.Op == "&&" and c1 == 0) or (node.Op == "||" and c1 ~= 0)
	if not runRight then
		return c1, o1, e1
	end

	local ok2, c2, o2, e2 = pcall(self.RunNode, self, node.Right, stdin)
	if not ok2 then
		rethrow(c2, o1, e1)
	end
	return c2, joinOutput(o1, o2), joinOutput(e1, e2)
end

--[=[
	Starts a job in the background.

	@param node The syntax tree node to evaluate.
]=]
function Shell:RunBackground(node)
	self.JobSeq += 1
	local id = self.JobSeq

	local job = {
		Id = id,
		Done = false,
		Code = nil,
		Output = "",
		Command = "<background>",
	}
	table.insert(self.Jobs, job)
	self.LastBg = id

	local child = self:Clone()
	task.spawn(function()
		local ok, code, output, errorValue = pcall(child.RunNode, child, node, "")
		job.Done = true
		job.Code = if ok then code or 0 else 1
		job.Output = output or ""

		if errorValue and errorValue ~= "" then
			child.Service:PrintTo(child.Executor, errorValue)
		end
		if job.Output ~= "" then
			child.Service:PrintTo(child.Executor, job.Output)
		end
	end)
end

--[=[
	Runs a `;` or `&` list.

	@param node The syntax tree node to evaluate.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
function Shell:RunList(node, stdin)
	if node.Op == "&" then
		self:RunBackground(node.Left)
		if node.Right then
			return self:RunNode(node.Right, stdin)
		end
		return 0, "", ""
	end

	local ok1, c1, o1, e1 = pcall(self.RunNode, self, node.Left, stdin)
	if not ok1 then
		rethrow(c1, nil, nil)
	end
	if self.ExitRequested then
		return c1, o1, e1
	end

	local ok2, c2, o2, e2 = pcall(self.RunNode, self, node.Right, stdin)
	if not ok2 then
		rethrow(c2, o1, e1)
	end
	return c2, joinOutput(o1, o2), joinOutput(e1, e2)
end

--[=[
	Runs an `if`, `elif` and `else` chain.

	@param node The syntax tree node to evaluate.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
function Shell:RunIf(node, stdin)
	for _, branch in node.Branches do
		self.ConditionDepth += 1
		local code, out, errorValue = self:RunNode(branch.Condition, stdin)
		self.ConditionDepth -= 1

		if code == 0 then
			local c, o, e = self:RunNode(branch.Body, stdin)
			return c, joinOutput(out, o), joinOutput(errorValue, e)
		end

		if self.ExitRequested then
			return code, out, errorValue
		end
	end

	if node.Else then
		return self:RunNode(node.Else, stdin)
	end

	return 0, "", ""
end

--[=[
	Runs a `while` or `until` loop.

	@param node The syntax tree node to evaluate.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
function Shell:RunWhile(node, stdin)
	local outputs = {}
	local errors = {}
	local lastCode = 0

	local readCommand = if stdin and stdin ~= "" then readCondition(node.Condition) else nil
	if readCommand then
		local lines = splitLines(stdin)
		local index = 1

		while index <= #lines do
			self:Step()

			local remaining = if index < #lines
				then table.concat(lines, "\n", index + 1) .. "\n"
				else ""

			self.ConditionDepth += 1
			local conditionCode, condOut, condErr =
				self:RunNode(node.Condition, lines[index] .. "\n")
			self.ConditionDepth -= 1

			if condOut ~= "" then
				table.insert(outputs, condOut)
			end
			if condErr ~= "" then
				table.insert(errors, condErr)
			end

			if self.ExitRequested then
				return self.ExitRequested, joinMany(outputs), joinMany(errors)
			end

			local keepGoing = if node.Until then conditionCode ~= 0 else conditionCode == 0
			if not keepGoing then
				break
			end

			local code, out, errorValue, control = self:RunLoopBody(node.Body, remaining)
			lastCode = code
			if out ~= "" then
				table.insert(outputs, out)
			end
			if errorValue ~= "" then
				table.insert(errors, errorValue)
			end

			if self.ExitRequested then
				return self.ExitRequested, joinMany(outputs), joinMany(errors)
			end

			if control then
				if control.Kind == "break" then
					if control.Value > 1 then
						control.Value -= 1
						error(control, 0)
					end
					break
				elseif control.Kind == "continue" then
					if control.Value > 1 then
						control.Value -= 1
						error(control, 0)
					end
				end
			end

			index += 1
		end

		self.Status = lastCode
		return lastCode, joinMany(outputs), joinMany(errors)
	end

	while true do
		self:Step()
		self.ConditionDepth += 1
		local conditionCode, condOut, condErr = self:RunNode(node.Condition, stdin)
		self.ConditionDepth -= 1

		if condOut ~= "" then
			table.insert(outputs, condOut)
		end
		if condErr ~= "" then
			table.insert(errors, condErr)
		end

		if self.ExitRequested then
			return self.ExitRequested, joinMany(outputs), joinMany(errors)
		end

		local keepGoing = if node.Until then conditionCode ~= 0 else conditionCode == 0
		if not keepGoing then
			break
		end

		local code, out, errorValue, control = self:RunLoopBody(node.Body, stdin)
		lastCode = code
		if out ~= "" then
			table.insert(outputs, out)
		end
		if errorValue ~= "" then
			table.insert(errors, errorValue)
		end

		if self.ExitRequested then
			return self.ExitRequested, joinMany(outputs), joinMany(errors)
		end

		if control then
			if control.Kind == "break" then
				if control.Value > 1 then
					control.Value -= 1
					error(control, 0)
				end
				break
			elseif control.Kind == "continue" then
				if control.Value > 1 then
					control.Value -= 1
					error(control, 0)
				end
			end
		end
	end

	self.Status = lastCode
	return lastCode, joinMany(outputs), joinMany(errors)
end

--[=[
	Runs a `for` loop over words or positional parameters.

	@param node The syntax tree node to evaluate.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
function Shell:RunFor(node, stdin)
	local items = if node.HasIn
		then Expander.expandWords(node.Words, self)
		else table.clone(self.Positional)
	local outputs = {}
	local errors = {}
	local lastCode = 0

	for _, item in items do
		self:SetVar(node.Name, item)

		local code, out, errorValue, control = self:RunLoopBody(node.Body, stdin)
		lastCode = code
		if out ~= "" then
			table.insert(outputs, out)
		end
		if errorValue ~= "" then
			table.insert(errors, errorValue)
		end

		if self.ExitRequested then
			return self.ExitRequested, joinMany(outputs), joinMany(errors)
		end

		if control then
			if control.Kind == "break" then
				if control.Value > 1 then
					control.Value -= 1
					error(control, 0)
				end
				break
			elseif control.Kind == "continue" then
				if control.Value > 1 then
					control.Value -= 1
					error(control, 0)
				end
			end
		end
	end

	self.Status = lastCode
	return lastCode, joinMany(outputs), joinMany(errors)
end

--[=[
	Runs a C-style arithmetic `for` loop.

	@param node The syntax tree node to evaluate.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
function Shell:RunForArith(node, stdin)
	local outputs = {}
	local errors = {}
	local lastCode = 0

	if node.Init and node.Init ~= "" then
		self:Arithmetic(node.Init)
	end

	while node.Cond == "" or self:Arithmetic(node.Cond) ~= 0 do
		self:Step()

		local code, out, errorValue, control = self:RunLoopBody(node.Body, stdin)
		lastCode = code
		if out ~= "" then
			table.insert(outputs, out)
		end
		if errorValue ~= "" then
			table.insert(errors, errorValue)
		end

		if self.ExitRequested then
			return self.ExitRequested, joinMany(outputs), joinMany(errors)
		end

		if control and control.Kind == "break" then
			if control.Value > 1 then
				control.Value -= 1
				error(control, 0)
			end
			break
		end
		if control and control.Kind == "continue" and control.Value > 1 then
			control.Value -= 1
			error(control, 0)
		end

		if node.Step and node.Step ~= "" then
			self:Arithmetic(node.Step)
		end
	end

	self.Status = lastCode
	return lastCode, joinMany(outputs), joinMany(errors)
end

--[=[
	Runs a `case` statement.

	@param node The syntax tree node to evaluate.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
function Shell:RunCase(node, stdin)
	local word = Expander.expandWordSingle(node.Word, self)
	local outputs = {}
	local errors = {}
	local code = 0
	local fallthrough = false

	for _, item in node.Items do
		local run = fallthrough

		if not run then
			for _, patternToken in item.Patterns do
				local pattern = Expander.expandWordSingle(patternToken, self)
				if Glob.match(word, pattern) then
					run = true
					break
				end
			end
		end

		if run then
			local c, out, errorValue = self:RunNode(item.Body, stdin)
			code = c
			if out ~= "" then
				table.insert(outputs, out)
			end
			if errorValue ~= "" then
				table.insert(errors, errorValue)
			end

			if self.ExitRequested then
				return self.ExitRequested, joinMany(outputs), joinMany(errors)
			end

			if item.Terminator == ";&" then
				fallthrough = true
			elseif item.Terminator == ";;&" then
				fallthrough = false
			else
				break
			end
		else
			fallthrough = false
		end
	end

	return code, joinMany(outputs), joinMany(errors)
end

--[=[
	Runs a compound command with its redirections.

	@param node The syntax tree node to evaluate.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
function Shell:RunRedirectNode(node, stdin)
	local input, redirectInfo = self:ApplyRedirects(node.Redirects, stdin)
	local code, output, errorValue = self:RunNode(node.Command or node.Body, input)

	if type(redirectInfo) == "table" then
		if redirectInfo.OutToErr then
			errorValue = joinOutput(output, errorValue)
			output = ""
		end
		if redirectInfo.MergeErr then
			output = joinOutput(output, errorValue)
			errorValue = ""
		end
		if redirectInfo.Out then
			local success, message = self:Redirect(output, redirectInfo.Out)
			if not success then
				errorValue = joinOutput(errorValue, message)
				code = 1
			end
			output = ""
		end
		if redirectInfo.Err then
			local success, message = self:Redirect(errorValue, redirectInfo.Err)
			if not success then
				errorValue = joinOutput(errorValue, message)
				code = 1
			end
			errorValue = ""
		end
	end

	return code, output, errorValue
end

--[=[
	Dispatches an AST node to its evaluator.

	@param node The syntax tree node to evaluate.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
function Shell:RunNode(node, stdin): (number, string, string)
	if not node then
		return 0, "", ""
	end

	self:Step()

	local kind = node.type

	if node.Redirects and kind ~= "Simple" and kind ~= "Group" then
		local inner = table.clone(node)
		inner.Redirects = nil
		return self:RunRedirectNode({ Redirects = node.Redirects, Body = inner }, stdin)
	end

	if kind == "Simple" then
		return self:RunSimple(node, stdin)
	elseif kind == "Pipeline" then
		return self:RunPipeline(node, stdin)
	elseif kind == "AndOr" then
		return self:RunAndOr(node, stdin)
	elseif kind == "List" then
		return self:RunList(node, stdin)
	elseif kind == "If" then
		return self:RunIf(node, stdin)
	elseif kind == "For" then
		return self:RunFor(node, stdin)
	elseif kind == "ForArith" then
		return self:RunForArith(node, stdin)
	elseif kind == "Arith" then
		local value = self:Arithmetic(node.Expression)
		local code = if value ~= 0 then 0 else 1
		self.Status = code
		return code, "", ""
	elseif kind == "While" then
		return self:RunWhile(node, stdin)
	elseif kind == "Case" then
		return self:RunCase(node, stdin)
	elseif kind == "Function" then
		self.Functions[node.Name] = node.Body
		return 0, "", ""
	elseif kind == "Group" then
		if node.Redirects then
			return self:RunRedirectNode({ Redirects = node.Redirects, Body = node.Body }, stdin)
		end
		return self:RunNode(node.Body, stdin)
	elseif kind == "Subshell" then
		local child = self:Clone()
		local code, output, errorValue = child:RunNode(node.Body, stdin)
		self.Steps = math.max(self.Steps, child.Steps)
		return code, output, errorValue
	end

	return 1, "", `unknown AST node: {tostring(kind)}`
end

--// Entry points //--

--[=[
	Parses and runs a line of shell input.

	@param line The line to process.
	@param stdin The piped standard input.
	@return The exit status, standard output and standard error.
]=]
function Shell:RunString(line: string, stdin: string?): (number, string, string)
	local tokens = Lexer.lex(line)
	local ast = Parser.parse(tokens)
	if not ast then
		return 0, "", ""
	end
	return self:RunNode(ast, stdin or "")
end

--[=[
	Resets per-line state and runs one input line.

	@param line The line to process.
	@return The exit status, standard output and standard error.
]=]
function Shell:RunLine(line: string): (number, string, string)
	self.Steps = 0
	self.PipeStatuses = {}

	local ok, a, b, c = pcall(self.RunString, self, line, "")

	if ok then
		local code = a or 0
		if self.ExitRequested then
			code = self.ExitRequested
			self.ExitRequested = nil
		end

		local trapAction = self.Traps and self.Traps.EXIT
		if trapAction and trapAction ~= "" then
			self.Traps.EXIT = nil
			local trapOk, trapCode, trapOut, trapErr = pcall(self.RunString, self, trapAction, "")
			if trapOk then
				b = joinOutput(b, trapOut)
				c = joinOutput(c, trapErr)
				if code == 0 and trapCode then
					code = trapCode
				end
			else
				c = joinOutput(c, tostring(trapCode))
			end
		end

		self.Status = code
		return code, cap(b), cap(c)
	end

	if type(a) == "table" and a.__shellControl then
		if a.Kind == "exit" then
			self.Status = a.Value
			return a.Value, "", ""
		elseif a.Kind == "break" then
			return 1, "", "break: only meaningful in a `for', `while', or `until' loop"
		elseif a.Kind == "continue" then
			return 1, "", "continue: only meaningful in a `for', `while', or `until' loop"
		end
		return 1, "", "return: can only `return' from a function or sourced script"
	end

	return 1, "", tostring(a)
end

return Shell
