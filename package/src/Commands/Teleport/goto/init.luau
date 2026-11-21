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
	Implements the `goto` command: Teleports you to a player.
]=]

return {
	Name = "goto",
	Description = "Teleports you to a player",
	Permission = "Moderator",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player to teleport to" },
	},
	--[=[
		Teleports you to a player.

		@param context The command context.
		@param target The player to teleport to
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player)
		local executor = context.Executor
		if executor.Character and executor.Character:FindFirstChild("HumanoidRootPart") then
			if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
				context.Terminal:SavePos(executor)
				executor.Character.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame
					* CFrame.new(0, 0, -5)
				return `Teleported to {target.Name}`
			end
		end
		context:Error("Could not teleport")
	end,
}
