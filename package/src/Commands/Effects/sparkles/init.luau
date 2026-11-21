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
	Implements the `sparkles` command: Adds sparkles to a player.
]=]

return {
	Name = "sparkles",
	Description = "Adds sparkles to a player",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player" },
	},
	--[=[
		Adds sparkles to a player.

		@param context The command context.
		@param target The player
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player)
		if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			local s = target.Character.HumanoidRootPart:FindFirstChild("AdminSparkles")
			if not s then
				s = Instance.new("Sparkles")
				s.Name = "AdminSparkles"
				s.Parent = target.Character.HumanoidRootPart
			end
			return `Added sparkles to {target.Name}`
		end
		context:Error(`Could not add sparkles to {target.Name}`)
	end,
}
