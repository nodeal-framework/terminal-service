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
	Implements the `back` command: Returns to the most recent saved position
	before a teleport (stack of last 10 positions).
]=]

return {
	Name = "back",
	Permission = "Moderator",
	Description = "Returns to the most recent saved position before a teleport (stack of last 10 "
		.. "positions)",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player", Default = "me" },
	},
	--[=[
		Returns to the most recent saved position before a teleport (stack of last
		10 positions).

		@param context The command context.
		@param target Player
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target)
		local TerminalService = context.Terminal
		local stack = TerminalService.LastPos and TerminalService.LastPos[target.UserId]
		if not stack or #stack == 0 then
			return `No saved positions for {target.Name}`
		end

		if not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
			context:Error(`{target.Name} has no character`)
			return
		end

		local position = table.remove(stack)
		context.Terminal:SavePos(target)
		target.Character.HumanoidRootPart.CFrame = position
		return `Returned {target.Name} to saved position ({#stack} remaining)`
	end,
}
