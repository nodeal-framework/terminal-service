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
	Implements the `forcefield` command: Applies a ForceField to a player's
	character.
]=]

return {
	Name = "forcefield",
	Aliases = { "ff" },
	Permission = "Admin",
	Description = "Applies a ForceField to a player's character",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
	},
	--[=[
		Applies a ForceField to a player's character.

		@param context The command context.
		@param target Player
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player)
		if not target.Character then
			context:Error(`{target.Name} has no character`)
			return
		end
		if target.Character:FindFirstChildOfClass("ForceField") then
			return `{target.Name} already has a ForceField`
		end
		local ff = Instance.new("ForceField")
		ff.Parent = target.Character
		return `ForceField applied to {target.Name}`
	end,
}
