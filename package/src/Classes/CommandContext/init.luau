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
	Everything a command receives when it runs.

	Carries the executor, raw and typed arguments, piped input, the shell and the
	exit status, and exposes Reply, Error and Success so commands never print directly.
]=]

local CommandContext = {}
CommandContext.__index = CommandContext

--[=[
	Creates the context handed to one command invocation.

	@param executor The player running the command.
	@param arguments The command arguments.
	@param input The input to process.
	@param terminalService The terminal service.
	@param shell The shell instance.

	@return The new context.
]=]
function CommandContext.new(
	executor: Player,
	arguments: { string },
	input: string?,
	terminalService: table,
	shell: any?
)
	local self = setmetatable({}, CommandContext)

	self.Executor = executor
	self.Args = arguments
	self.Input = input or ""
	self.Output = ""
	self.ErrorMsg = ""
	self.Code = 0
	self.Terminal = terminalService
	self.Shell = shell

	return self
end

--[=[
	Appends a line to standard output.

	@param message The message to show.
]=]
function CommandContext:Reply(message: string): ()
	if self.Output ~= "" then
		self.Output ..= "\n" .. message
	else
		self.Output = message
	end
end

--[=[
	Appends a line to standard error and sets the exit status.

	@param message The message to show.
	@param code The exit status.
]=]
function CommandContext:Error(message: string, code: number?): ()
	if self.ErrorMsg ~= "" then
		self.ErrorMsg ..= "\n" .. message
	else
		self.ErrorMsg = message
	end
	self.Code = code or 1
end

--[=[
	Sets the exit status of the command.

	@param code The exit status.
]=]
function CommandContext:SetCode(code: number): ()
	self.Code = code
end

--[=[
	Returns the piped input for this command.

	@return The resulting text.
]=]
function CommandContext:GetInput(): string
	return self.Input
end

--[=[
	Returns true when the command exited with status zero.

	@return True when the condition holds.
]=]
function CommandContext:Success(): boolean
	return self.Code == 0
end

return CommandContext
