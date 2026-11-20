--[[
    © 2026 Nodeal Package. All rights reserved.

    This source code is open-source and free for modification and use in your projects.
    However, you may not sell, sublicense, or distribute this framework (or 
    any rebranded version of it) as a standalone product.

    Any public use or redistribution of this module requires this header 
    to remain intact in the source code. For the complete license terms, 
    please visit: https://www.nodeal.dev/license
]]

local __=_G() local TerminalService = {}
TerminalService.__index = TerminalService

--// Services //--
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local BridgeService = game:GetService("BridgeService")

--// Modules //--
local Lexer = require(script.Parser.Lexer)
local Expander = require(script.Parser.Expander)
local Parser = require(script.Parser.Parser)
local CommandContext = require(script.Classes.CommandContext)
local Command = require(script.Classes.Command)

--// Private //--
local Network = BridgeService:GetNetwork("TerminalService")

local _commands = {}
local _aliases = {}
local _types = {}

local _history = {}
local _historyMax = 200
local _serverStart = os.clock()

-- What one line from a client may cost the server, checked before any of it runs.
local MAX_LINE = 500 -- characters
local MAX_TOKENS = 256 -- words, once braces are expanded
local MAX_COMMANDS = 16 -- commands chained with ; && || | >
local MAX_OUTPUT = 16384 -- characters sent back or redirected

local OPERATORS = { [";"] = true, ["&&"] = true, ["||"] = true, ["|"] = true, [">"] = true }

-- A command that declares no Permission is admin-only: forgetting the field must not open it to every client.
TerminalService.DefaultPermission = script:GetAttribute("DefaultPermission") or "Admin"
-- Printing into another player's console (`cmd > player`) is a broadcast.
TerminalService.RedirectPermission = script:GetAttribute("RedirectPermission") or "Moderator"

--// Helpers //--
local function allowed(executor: Player?, permission: any): boolean
	if not executor or permission == "Any" then
		return true
	end

	local auth = TerminalService.AuthorizationService
	return auth ~= nil and auth:HasPermissionAsync(executor, permission) == true
end

local function cap(text: any): any
	if type(text) == "string" and #text > MAX_OUTPUT then
		return string.sub(text, 1, MAX_OUTPUT) .. "\n[output truncated]"
	end

	return text
end

-- What a player typed, fit for every reader. Nil when Roblox's filter does not answer: nothing unfiltered goes out.
local function filtered(from: Player?, text: any): any
	if not from or type(text) ~= "string" or text == "" then
		return text
	end

	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, from.UserId, Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync()
	end)

	return if ok then result else nil
end

-- The terminal a command sees: what its player sends to others is filtered first. Everything else is the service itself.
local function terminalFor(executor: Player?): any
	if not executor then
		return TerminalService
	end

	local cache = {}

	local function clean(message: any): any
		local text = cache[message]

		if text == nil then
			text = filtered(executor, message)
			if text == nil then
				error("the text filter did not answer, nothing was sent", 0)
			end
			cache[message] = text
		end

		return text
	end

	return setmetatable({
		Broadcast = function(_, message: string, kind: string?)
			TerminalService:Broadcast(clean(message), kind)
		end,
		PrintTo = function(_, target: any, message: string, kind: string?)
			TerminalService:PrintTo(target, clean(message), kind)
		end,
		SendSystemChat = function(_, target: any, message: string)
			TerminalService:SendSystemChat(target, clean(message))
		end,
	}, { __index = TerminalService, __newindex = TerminalService })
end

local function evaluateAST(node: any, stdin: string, executor: Player): (number, string, string)
	if not node then return 0, "", "" end

	if node.type == "Command" then
		local command = TerminalService:GetCommand(node.name)
		if not command then
			return 1, "", `Command '{node.name}' not found`
		end

		local context = CommandContext.new(executor, node.args, stdin, terminalFor(executor))
		command:Execute(context, node.args, TerminalService)

		return context.Code, context.Output, context.ErrorMsg

	elseif node.type == "Redirect" then
		local code, stdout, stderr = evaluateAST(node.command, stdin, executor)
		if code ~= 0 then
			return code, stdout, stderr
		end

		if stdout ~= "" then
			local targets = {}
			local playerType = TerminalService:GetType("Player")

			if playerType then
				if playerType.Validate(node.target, executor) then
					local target = playerType.Transform(node.target, executor)
					if type(target) == "table" and target.__isMultiValue then
						targets = target.Values
					elseif typeof(target) == "Instance" and target:IsA("Player") then
						targets = { target }
					end
				end
			else
				local targetPlayer = Players:FindFirstChild(node.target)
				if targetPlayer and targetPlayer:IsA("Player") then
					targets = { targetPlayer }
				end
			end

			-- anyone could print into every console with `echo ... > all`
			local others = false
			for _, p in targets do
				if p ~= executor then
					if not allowed(executor, TerminalService.RedirectPermission) then
						return 1, "", "redirect: permission denied"
					end
					others = true
				end
			end

			stdout = cap(stdout)

			if others then
				stdout = filtered(executor, stdout)
				if stdout == nil then
					return 1, "", "redirect: the text filter did not answer, nothing was sent"
				end
			end

			for _, p in targets do
				Network:Fire(p, "RedirectPrint", stdout)
			end
		end

		return 0, "", ""

	elseif node.type == "Pipeline" then
		local code1, stdout1, stderr1 = evaluateAST(node.left, stdin, executor)
		if code1 ~= 0 then
			return code1, stdout1, stderr1
		end

		return evaluateAST(node.right, stdout1, executor)

	elseif node.type == "Logical" then
		if node.op == ";" then
			local code1, stdout1, stderr1 = evaluateAST(node.left, stdin, executor)
			local code2, stdout2, stderr2 = evaluateAST(node.right, stdin, executor)

			local combinedStdout = stdout1 .. (stdout1 ~= "" and stdout2 ~= "" and "\n" or "") .. stdout2
			local combinedStderr = stderr1 .. (stderr1 ~= "" and stderr2 ~= "" and "\n" or "") .. stderr2
			local code = (code1 ~= 0 or code2 ~= 0) and 1 or 0

			return code, combinedStdout, combinedStderr

		elseif node.op == "&&" then
			local code1, stdout1, stderr1 = evaluateAST(node.left, stdin, executor)
			if code1 == 0 then
				local code2, stdout2, stderr2 = evaluateAST(node.right, stdin, executor)
				local combinedStdout = stdout1 .. (stdout1 ~= "" and stdout2 ~= "" and "\n" or "") .. stdout2
				return code2, combinedStdout, stderr2
			end
			return code1, stdout1, stderr1

		elseif node.op == "||" then
			local code1, stdout1, stderr1 = evaluateAST(node.left, stdin, executor)
			if code1 ~= 0 then
				local code2, stdout2, stderr2 = evaluateAST(node.right, stdin, executor)
				return code2, stdout2, stderr2
			end
			return code1, stdout1, stderr1
		end
	end

	return 1, "", "Unknown AST Node type"
end

function TerminalService.FuzzyMatch(query: string, target: string): number
	if not query or query == "" then return 10 end
	query = string.lower(query)
	target = string.lower(target)

	if query == target then return 100 end
	if string.sub(target, 1, #query) == query then return 90 end

	local qIdx = 1
	local tIdx = 1
	while tIdx <= #target and qIdx <= #query do
		if string.sub(query, qIdx, qIdx) == string.sub(target, tIdx, tIdx) then
			qIdx += 1
		end
		tIdx += 1
	end
	if qIdx > #query then
		return 70
	end

	local prefixTarget = string.sub(target, 1, #query)
	local len1 = #query
	local len2 = #prefixTarget
	local matrix = {}
	for i = 0, len1 do matrix[i] = {[0] = i} end
	for j = 0, len2 do matrix[0][j] = j end

	for i = 1, len1 do
		for j = 1, len2 do
			local cost = (string.sub(query, i, i) == string.sub(prefixTarget, j, j)) and 0 or 1
			matrix[i][j] = math.min(
				matrix[i-1][j] + 1,
				matrix[i][j-1] + 1,
				matrix[i-1][j-1] + cost
			)
			if i > 1 and j > 1 and string.sub(query, i, i) == string.sub(prefixTarget, j-1, j-1) and string.sub(query, i-1, i-1) == string.sub(prefixTarget, j, j) then
				matrix[i][j] = math.min(matrix[i][j], matrix[i-2][j-2] + cost)
			end
		end
	end

	local dist = matrix[len1][len2]

	if #query > #target and string.sub(query, -1) == " " then
		return 0
	end

	local maxAllowed = math.floor(#query / 3)
	if dist <= maxAllowed then
		return 50 - dist
	end

	return 0
end

--// Public //--
function TerminalService:GetTypes()
	return _types
end

--[=[
	Registers a new command in the terminal registry.
]=]
function TerminalService:RegisterCommand(config: table): ()
	if not config.Name then warn("Missing command name for:", config, "skipping") return end
	
	local cmd = Command.new(config)
	cmd.Permission = cmd.Permission or TerminalService.DefaultPermission
	_commands[config.Name] = cmd

	for _, alias in cmd.Aliases do
		_aliases[alias] = config.Name
	end
end

--[=[
	Retrieves a command by its name or alias.
]=]
function TerminalService:GetCommand(name: string): any?
	local realName = _aliases[name] or name
	return _commands[realName]
end

--[=[
	Returns all registered commands.
]=]
function TerminalService:GetCommands(): { [string]: any }
	local copy = {}
	for name, cmd in _commands do
		copy[name] = cmd
	end
	return copy
end

--[=[
	Registers a new argument type parser.
]=]
function TerminalService:RegisterType(typeName: string, parser: table): ()
	_types[typeName] = parser
end

--[=[
	Retrieves an argument type parser.
]=]
function TerminalService:GetType(typeName: string): any?
	local primaryType = string.match(typeName, "^([^|?]+)")
	if primaryType then
		primaryType = string.match(primaryType, "^%s*(.-)%s*$")
		return _types[primaryType]
	end
	return _types[typeName]
end

--[=[
	Executes a Linux CLI command line.
	Returns (code: number, stdout: string, stderr: string).
]=]
function TerminalService:Execute(line: string, executor: Player?): (number, string, string)
	if RunService:IsClient() then
		return Network:Invoke("Execute", line)
	end

	local entry = { line = line, time = os.time(), executor = executor and executor.Name or "<server>" }
	table.insert(_history, entry)
	if #_history > _historyMax then
		table.remove(_history, 1)
	end

	local results = table.pack(pcall(function()
		local rawTokens = Lexer.tokenize(line)
		local expandedTokens = Expander.expand(rawTokens)

		if #expandedTokens > MAX_TOKENS then
			error(`too many words (more than {MAX_TOKENS})`, 0)
		end

		local commands = 1
		for _, token in expandedTokens do
			if OPERATORS[token] then
				commands += 1
			end
		end

		if commands > MAX_COMMANDS then
			error(`too many commands in one line (more than {MAX_COMMANDS})`, 0)
		end

		local ast = Parser.parse(expandedTokens)

		if not ast then
			return 0, "", ""
		end

		return evaluateAST(ast, "", executor)
	end))

	local status = results[1]
	if not status then
		return 1, "", `Parser Error: {tostring(results[2])}`
	end

	if executor then
		return results[2], cap(results[3]), cap(results[4])
	end

	return table.unpack(results, 2, results.n)
end

function TerminalService:GetHistory(): { { line: string, time: number, executor: string } }
	local copy = {}
	for i, entry in _history do
		copy[i] = entry
	end
	return copy
end

function TerminalService:GetUptime(): number
	return os.clock() - _serverStart
end

-- A colon: every caller writes Terminal:Broadcast(...), and the dot made the service itself the message.
function TerminalService:Broadcast(message: string, kind: string?)
	if RunService:IsClient() then return end
	local payload = { Message = message, Kind = kind or "Normal" }
	for _, p in Players:GetPlayers() do
		Network:Fire(p, "TerminalPrint", payload)
	end
end

function TerminalService:PrintTo(target: any, message: string, kind: string?)
	if RunService:IsClient() then return end
	local payload = { Message = message, Kind = kind or "Normal" }
	local function fireOne(p: Player)
		Network:Fire(p, "TerminalPrint", payload)
	end

	if type(target) == "table" then
		if target.__isMultiValue then
			for _, p in target.Values do
				if typeof(p) == "Instance" and p:IsA("Player") then
					fireOne(p)
				end
			end
		else
			for _, p in target do
				if typeof(p) == "Instance" and p:IsA("Player") then
					fireOne(p)
				end
			end
		end
	elseif typeof(target) == "Instance" and target:IsA("Player") then
		fireOne(target)
	end
end

function TerminalService:SendSystemChat(target: any, message: string)
	if RunService:IsClient() then return end

	local function fireOne(p: Player)
		Network:Fire(p, "SystemChat", message)
	end

	if type(target) == "table" then
		if target.__isMultiValue then
			for _, p in target.Values do
				if typeof(p) == "Instance" and p:IsA("Player") then
					fireOne(p)
				end
			end
		else
			for _, p in target do
				if typeof(p) == "Instance" and p:IsA("Player") then
					fireOne(p)
				end
			end
		end
	elseif typeof(target) == "Instance" and target:IsA("Player") then
		fireOne(target)
	end
end

function TerminalService:SavePos(target: Player)
	if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then return end
	if not self.LastPos then self.LastPos = {} end
	local stack = self.LastPos[target.UserId]
	if not stack then
		stack = {}
		self.LastPos[target.UserId] = stack
	end
	table.insert(stack, target.Character.HumanoidRootPart.CFrame)
	while #stack > 10 do
		table.remove(stack, 1)
	end
end

--[=[
	Returns autocomplete data for a given input line.
]=]
-- What a command takes, as the terminal's suggestions show it: "<title> <body>".
local function usageOf(command): string
	local parts = {}
	for _, arg in command.Args or {} do
		table.insert(parts, `<{string.lower(arg.Name or arg.name or "arg")}>`)
	end
	return table.concat(parts, " ")
end

-- Autocomplete crosses BridgeService, which cannot serialize functions. A command may declare a
-- dynamic Type as a function: resolve it here, and send only the fields the client UI reads.
local function clientArgs(args, rawArgs): { any }
	local list = {}

	for i, arg in args or {} do
		local argType = arg.Type or arg.type or "string"

		if type(argType) == "function" then
			local ok, resolved = pcall(argType, rawArgs)
			argType = if ok and type(resolved) == "string" then resolved else "string"
		elseif type(argType) ~= "string" then
			argType = "string"
		end

		-- Copy the fields the command declared (custom type options included), minus functions.
		local sanitized = {}
		for key, value in arg do
			if type(value) ~= "function" then
				sanitized[key] = value
			end
		end

		sanitized.Name = arg.Name or arg.name or "unknown"
		sanitized.Type = argType
		list[i] = sanitized
	end

	return list
end

function TerminalService:GetAutocompleteSuggestions(line: string, player: Player?): any
	if RunService:IsClient() then
		return Network:Invoke("Autocomplete", line)
	end

	local tokens = Lexer.tokenize(line)
	local endsWithSpace = string.match(line, "%s$") ~= nil

	if #tokens == 0 then
		local list = {}
		for name, cmd in _commands do
			table.insert(list, { Text = name, Description = cmd.Description or "", Usage = usageOf(cmd), Category = cmd.Category })
		end
		return { Suggestions = list }
	end

	local lastOpIdx = 0
	local lastOp = nil
	for i = #tokens, 1, -1 do
		local t = tokens[i]
		if t == ";" or t == "&&" or t == "||" or t == "|" or t == ">" then
			lastOpIdx = i
			lastOp = t
			break
		end
	end

	local cmdStartIdx = lastOpIdx + 1

	if lastOp == ">" then
		local currentArgText = ""
		if cmdStartIdx <= #tokens then
			local remaining = {}
			for i = cmdStartIdx, #tokens do table.insert(remaining, tokens[i]) end
			currentArgText = table.concat(remaining, " ")
			if endsWithSpace and #remaining > 0 then
				currentArgText = currentArgText .. " "
			end
		end

		local typeParser = TerminalService:GetType("Player")
		if typeParser and typeParser.Autocomplete then
			local suggestions = typeParser.Autocomplete(currentArgText, player, TerminalService)
			if type(suggestions) == "table" then
				if not suggestions.Suggestions then
					suggestions = { Suggestions = suggestions }
				end
				suggestions.CurrentArgText = currentArgText
				return suggestions
			end
		end
		return { Suggestions = {} }
	end

	if cmdStartIdx > #tokens or (cmdStartIdx == #tokens and not endsWithSpace) then
		local prefix = ""
		if cmdStartIdx == #tokens then
			prefix = string.lower(tokens[cmdStartIdx])
		end

		local list = {}
		for name, cmd in _commands do
			local score = TerminalService.FuzzyMatch(prefix, name)
			if score > 0 then
				table.insert(list, { Text = name, Description = cmd.Description or "", Usage = usageOf(cmd), Category = cmd.Category, Score = score })
			end
		end
		for alias, cmdName in _aliases do
			local score = TerminalService.FuzzyMatch(prefix, alias)
			if score > 0 then
				local cmd = _commands[cmdName]
				table.insert(list, { Text = alias, Description = `Alias for {cmdName}`, Usage = cmd and usageOf(cmd) or "", Category = cmd and cmd.Category, Score = score })
			end
		end
		table.sort(list, function(a, b) return (a.Score or 0) > (b.Score or 0) end)
		return { Suggestions = list, CurrentArgText = prefix }
	end

	local cmdName = tokens[cmdStartIdx]
	local command = TerminalService:GetCommand(cmdName)
	if not command then return { Suggestions = {} } end

	local argIdx = (#tokens - cmdStartIdx)
	if endsWithSpace then
		argIdx += 1
	end

	local currentArgText = ""

	if argIdx >= #command.Args then
		argIdx = #command.Args

		local remaining = {}
		for i = cmdStartIdx + argIdx, #tokens do
			table.insert(remaining, tokens[i])
		end
		currentArgText = table.concat(remaining, " ")
		if endsWithSpace and #remaining > 0 then
			currentArgText = currentArgText .. " "
		end
	else
		currentArgText = tokens[#tokens]
		if endsWithSpace then
			currentArgText = ""
		end
	end

	local rawArgs = {}
	for i = 2, #tokens do
		table.insert(rawArgs, tokens[i])
	end

	local cmdInfo = {
		Name = command.Name,
		Description = command.Description,
		Args = clientArgs(command.Args, rawArgs)
	}

	local argSpec = command.Args[argIdx]
	if not argSpec then 
		return { Suggestions = {}, CommandInfo = cmdInfo, ActiveArgIndex = argIdx } 
	end

	local argType = argSpec.Type or argSpec.type
	if type(argType) == "function" then
		argType = argType(rawArgs) or "string"
	elseif type(argType) ~= "string" then
		argType = "string"
	end
	local types = string.split(string.gsub(argType, "%s+", ""), "|")
	local richSuggestions = {}

	for _, tName in ipairs(types) do
		local typeParser = TerminalService:GetType(tName)
		if typeParser then
			local suggestions = typeParser.Autocomplete(currentArgText, player, TerminalService, argSpec)
			for _, sug in suggestions do
				if type(sug) == "string" then
					table.insert(richSuggestions, { Text = sug, Description = "", Score = 0 })
				elseif type(sug) == "table" and sug.Text then
					table.insert(richSuggestions, { Text = sug.Text, DisplayText = sug.DisplayText, Description = sug.Description or "", Icon = sug.Icon, Color = sug.Color, Score = sug.Score or 0 })
				end
			end
		end
	end

	table.sort(richSuggestions, function(a, b) return (a.Score or 0) > (b.Score or 0) end)

	return { 
		Suggestions = richSuggestions, 
		CommandInfo = cmdInfo, 
		ActiveArgIndex = argIdx,
		CurrentArgText = currentArgText,
		ActiveArgType = argType
	}
end

function TerminalService.Init()
	TerminalService.Network = Network

	-- Register Types (Both Client and Server)
	for _, typeFolder in script.Types:GetChildren() do
		for _, file in typeFolder:GetChildren() do
			if file:IsA("ModuleScript") then
				local parser = require(file)
				TerminalService:RegisterType(file.Name, parser)
			end
		end
	end

	if RunService:IsServer() then
		TerminalService.AuthorizationService = game:GetService("AuthorizationService")

		-- IMPORTANT: Force creation of the RemoteEvent on the server so the client can hook it early!
		-- Without this, the very first Network:Fire will drop the packet because the client hasn't had time to hook it yet.
		Network:OnEvent(function() end)

		-- Register Commands
		local function loadCommands(parentFolder: Instance, category: string?)
			for _, child in parentFolder:GetChildren() do
				if child:IsA("ModuleScript") then
					local config = require(child)
					if not config then continue end
					if category and config.Category == nil then
						config.Category = category
					end
					TerminalService:RegisterCommand(config)
				elseif child:IsA("Folder") then
					loadCommands(child, child.Name)
				end
			end
		end
		loadCommands(script.Commands)

		-- Network Hook
		Network:OnInvoke(function(header, action, ...)
			local player = header.Player
			if not player then return end

			-- bounded before lexing: a client must not make the server pay for an arbitrary line
			if action == "Execute" then
				local line = ...
				if type(line) ~= "string" then return 1, "", "Invalid input" end
				if #line > MAX_LINE then return 1, "", "Input too long" end
				return TerminalService:Execute(line, player)
			elseif action == "Autocomplete" then
				local line = ...
				if type(line) ~= "string" then return {} end
				if #line > MAX_LINE then return {} end
				return TerminalService:GetAutocompleteSuggestions(line, player)
			end
		end)
	else
		task.spawn(function()
			local displayModule = script:FindFirstChild("Display")
			if displayModule then
				local Display = require(displayModule)
				Display.Mount(TerminalService)
			end
		end)
	end
end

--[=[
	@export documentation arguments
]=]
game:RegisterDecorator("command", function(parent, func: (...any?) -> (...any?), desc: string, args: any, name: string): (...any?) -> (...any?)
	local userArgs = {}
	local passParent = false
	local passExecutor = false

	if args and type(args) == "table" then
		for i, argAst in ipairs(args) do
			local rawName = ""
			if argAst.kind == "variadic" then
				rawName = "..."
			else
				rawName = argAst.name or ""
			end

			local lowerArgName = string.lower(rawName)

			if i == 1 and lowerArgName == "self" then
				passParent = true
			elseif (i == 1 or (i == 2 and passParent)) and lowerArgName == "executor" then
				passExecutor = true
			else
				local argTypeStr = "string"
				local isOptional = false

				local function parseType(t)
					if type(t) ~= "table" then return "string" end
					if t.kind == "basic" or t.kind == "reference" then
						if t.name == "any" then return "string" end
						return t.name
					elseif t.kind == "optional" then
						isOptional = true
						return parseType(t.inner)
					elseif t.kind == "union" then
						local types = {}
						for _, ut in ipairs(t.types) do
							table.insert(types, parseType(ut))
						end
						return table.concat(types, "|")
					else
						return "string"
					end
				end

				if argAst.type then
					argTypeStr = parseType(argAst.type)
				end

				table.insert(userArgs, {
					Name = rawName,
					Type = argTypeStr,
					Optional = isOptional
				})
			end
		end
	end

	TerminalService:RegisterCommand({
		Name = name,
		Description = desc,
		Args = userArgs,
		Run = function(context, ...)
			local callArgs = {}
			if passParent then
				table.insert(callArgs, parent)
			end

			if passExecutor then
				table.insert(callArgs, context.Executor)
			elseif not passParent and not passExecutor then
				table.insert(callArgs, context.Executor)
			end

			for _, v in ipairs({ ... }) do
				table.insert(callArgs, v)
			end

			return func(table.unpack(callArgs))
		end
	})
	return func
end)

game:RegisterService("TerminalService", TerminalService)

return __(TerminalService)