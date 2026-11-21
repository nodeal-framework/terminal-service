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
	Implements the `freeze` command: Freezes a player in place.
]=]

return {
	Name = "freeze",
	Description = "Freezes a player in place",
	Permission = "Moderator",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player to freeze" },
	},
	--[=[
		Freezes a player in place.

		@param context The command context.
		@param target The player to freeze
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player)
		if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			target.Character.HumanoidRootPart.Anchored = true
			return `Froze {target.Name}`
		end
		context:Error(`Could not freeze {target.Name}`)
	end,
}
