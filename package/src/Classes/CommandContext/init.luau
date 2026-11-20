--[[
    © 2026 Nodeal Package. All rights reserved.

    This source code is open-source and free for modification and use in your projects.
    However, you may not sell, sublicense, or distribute this framework (or 
    any rebranded version of it) as a standalone product.

    Any public use or redistribution of this module requires this header 
    to remain intact in the source code. For the complete license terms, 
    please visit: https://www.nodeal.dev/license
]]

local CommandContext = {}
CommandContext.__index = CommandContext

function CommandContext.new(executor: Player, args: {string}, input: string?, terminalService: table)
	local self = setmetatable({}, CommandContext)

	self.Executor = executor
	self.Args = args
	self.Input = input or ""
	self.Output = ""
	self.ErrorMsg = ""
	self.Code = 0
	self.Terminal = terminalService

	return self
end

function CommandContext:Reply(msg: string): ()
	if self.Output ~= "" then
		self.Output ..= "\n" .. msg
	else
		self.Output = msg
	end
end

function CommandContext:Error(msg: string): ()
	if self.ErrorMsg ~= "" then
		self.ErrorMsg ..= "\n" .. msg
	else
		self.ErrorMsg = msg
	end
	self.Code = 1
end

function CommandContext:GetInput(): string
	return self.Input
end

function CommandContext:Success(): boolean
	return self.Code == 0
end

return CommandContext
