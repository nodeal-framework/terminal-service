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
	Implements the `smoke` command: Adds smoke to a player.
]=]

return {
	Name = "smoke",
	Description = "Adds smoke to a player",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player" },
	},
	--[=[
		Adds smoke to a player.

		@param context The command context.
		@param target The player
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player)
		if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			local s = target.Character.HumanoidRootPart:FindFirstChild("AdminSmoke")
			if not s then
				s = Instance.new("Smoke")
				s.Name = "AdminSmoke"
				s.Parent = target.Character.HumanoidRootPart
			end
			return `Added smoke to {target.Name}`
		end
		context:Error(`Could not add smoke to {target.Name}`)
	end,
}
