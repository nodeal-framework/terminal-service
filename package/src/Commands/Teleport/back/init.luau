return {
	Name = "back",
	Description = "Returns to the most recent saved position before a teleport (stack of last 10 positions)",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player", Default = "me" }
	},
	Run = function(context, target)
		local TerminalService = context.Terminal
		local stack = TerminalService.LastPos and TerminalService.LastPos[target.UserId]
		if not stack or #stack == 0 then return `No saved positions for {target.Name}` end

		if not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then
			context:Error(`{target.Name} has no character`)
			return
		end

		local pos = table.remove(stack)
		context.Terminal:SavePos(target)
		target.Character.HumanoidRootPart.CFrame = pos
		return `Returned {target.Name} to saved position ({#stack} remaining)`
	end
}
