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
	Command objects and their execution pipeline.

	Validates typed arguments through the registered argument types, enforces
	permissions and normalises the values a command returns into terminal output.
]=]

local Command = {}
Command.__index = Command

--[=[
	Creates a command object from its definition table.

	@param config The command definition table.

	@return The new command.
]=]
function Command.new(config: table)
	local self = setmetatable({}, Command)

	self.Name = config.Name
	self.Aliases = config.Aliases or {}
	self.Description = config.Description or ""
	self.Category = config.Category
	self.Permission = config.Permission
	self.Args = config.Args or {}
	self.Run = config.Run

	return self
end

-- Checked on every run. A command that declares no Permission falls back on
-- TerminalService's DefaultPermission ("Admin" unless changed): open commands
-- say Permission = "Any".
--[=[
	Checks whether the executor may run this command.

	@param command The command to run.
	@param context The command context.
	@param terminalService The terminal service.

	@return True when the condition holds.
]=]
local function isAllowed(command, context, terminalService): boolean
	local terminal = terminalService or (context and context.Terminal)
	local required = command.Permission or (terminal and terminal.DefaultPermission) or "Admin"

	if required == "Any" then
		return true
	end

	-- No executor: the server ran it itself, not a client.
	local executor = context and context.Executor

	if not executor then
		return true
	end

	local auth = terminal and terminal.AuthorizationService

	-- Fail closed: no authorization service means no privileged command.
	if not auth then
		return false
	end

	return auth:HasPermissionAsync(executor, required) == true
end

--[=[
	Validates arguments, runs the command and normalises its output.

	@param context The command context.
	@param rawArgs The raw argument tokens.
	@param terminalService The terminal service.

	@return The exit status, standard output and standard error.
]=]
function Command:Execute(context, rawArgs: { string }, terminalService)
	if not isAllowed(self, context, terminalService) then
		context:Error(`{self.Name}: permission denied`, 126)
		return
	end

	local validatedArgs = {}

	for index, argSpec in self.Args do
		local rawVal = rawArgs[index]

		if rawVal == nil and context.Input ~= nil and context.Input ~= "" then
			local argType = argSpec.Type or argSpec.type
			if type(argType) == "string" then
				for tName in string.gmatch(argType, "[^|%s]+") do
					if tName == "Player" then
						rawVal = context.Input
						break
					end
				end
			end
		end

		local argName = argSpec.Name or argSpec.name
		local argType = argSpec.Type or argSpec.type
		if type(argType) == "function" then
			argType = argType(rawArgs) or "string"
		end
		local argDesc = argSpec.Description or argSpec.description

		-- If this is the last argument, consume all remaining tokens joined by spaces
		if index == #self.Args and rawVal ~= nil then
			local remaining = {}
			for i = index, #rawArgs do
				table.insert(remaining, rawArgs[i])
			end
			rawVal = table.concat(remaining, " ")
		end

		if rawVal == nil then
			if argSpec.Default ~= nil then
				table.insert(validatedArgs, argSpec.Default)
			elseif argSpec.Optional or argSpec.optional then
				table.insert(validatedArgs, nil)
			else
				context:Error(`Missing argument '{argName}' ({argDesc or ""})`)
				return
			end
		else
			local types = string.split(string.gsub(argType, "%s+", ""), "|")
			local validParser = nil
			local lastErr = nil
			local value = nil

			for _, tName in ipairs(types) do
				local typeParser = terminalService:GetType(tName)
				if typeParser then
					local success, errorValue =
						typeParser.Validate(rawVal, context.Executor, terminalService, argSpec)
					if success then
						validParser = typeParser
						value =
							typeParser.Transform(rawVal, context.Executor, terminalService, argSpec)
						break
					else
						lastErr = errorValue
					end
				else
					lastErr = `Unknown argument type '{tName}'`
				end
			end

			if not validParser then
				context:Error(`Invalid value for '{argName}': {lastErr or "validation failed"}`)
				return
			end

			table.insert(validatedArgs, value)
		end
	end

	local multiArgIndex = nil
	local multiValues = nil

	for i, value in ipairs(validatedArgs) do
		if type(value) == "table" and value.__isMultiValue then
			if multiArgIndex then
				context:Error("Cannot use multiple multi-value arguments in the same command.")
				return
			end
			multiArgIndex = i
			multiValues = value.Values
		end
	end

	if multiArgIndex then
		local combinedOutputs = {}
		local hasErrors = false
		for _, v in ipairs(multiValues) do
			validatedArgs[multiArgIndex] = v
			local results = table.pack(pcall(function()
				return self.Run(context, table.unpack(validatedArgs))
			end))

			local status = results[1]
			if not status then
				if type(results[2]) == "table" and results[2].__shellControl then
					error(results[2], 0)
				end
				hasErrors = true
				table.insert(combinedOutputs, `[Error]: {tostring(results[2])}`)
			else
				local outputs = {}
				for j = 2, results.n do
					if results[j] ~= nil then
						table.insert(outputs, tostring(results[j]))
					end
				end
				if #outputs > 0 then
					table.insert(combinedOutputs, table.concat(outputs, " "))
				end
			end
		end

		if #combinedOutputs > 0 then
			if hasErrors then
				context:Error(table.concat(combinedOutputs, "\n"))
			else
				context:Reply(table.concat(combinedOutputs, "\n"))
			end
		end
	else
		local results = table.pack(pcall(function()
			return self.Run(context, table.unpack(validatedArgs))
		end))

		local status = results[1]
		if not status then
			if type(results[2]) == "table" and results[2].__shellControl then
				error(results[2], 0)
			end
			context:Error(`Runtime Error: {tostring(results[2])}`)
		else
			local outputs = {}
			for i = 2, results.n do
				local value = results[i]
				if value ~= nil then
					table.insert(outputs, tostring(value))
				end
			end

			if #outputs > 0 then
				context:Reply(table.concat(outputs, " "))
			end
		end
	end
end

return Command
