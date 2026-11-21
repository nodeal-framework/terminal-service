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
	Implements the `unforcefield` command: Removes the ForceField from a
	player's character.
]=]

return {
	Name = "unforcefield",
	Aliases = { "unff" },
	Permission = "Admin",
	Description = "Removes the ForceField from a player's character",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
	},
	--[=[
		Removes the ForceField from a player's character.

		@param context The command context.
		@param target Player
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player)
		if not target.Character then
			context:Error(`{target.Name} has no character`)
			return
		end
		local ff = target.Character:FindFirstChildOfClass("ForceField")
		if not ff then
			return `{target.Name} has no ForceField`
		end
		ff:Destroy()
		return `ForceField removed from {target.Name}`
	end,
}
