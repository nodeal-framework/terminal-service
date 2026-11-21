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
	Implements the `explode` command: Creates an explosion at a player.
]=]

return {
	Name = "explode",
	Description = "Creates an explosion at a player",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player" },
	},
	--[=[
		Creates an explosion at a player.

		@param context The command context.
		@param target The player
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player)
		if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			local e = Instance.new("Explosion")
			e.Position = target.Character.HumanoidRootPart.Position
			e.Parent = workspace
			return `Exploded {target.Name}`
		end
		context:Error(`Could not explode {target.Name}`)
	end,
}
