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
	Implements the `unsmoke` command: Removes smoke from a player.
]=]

return {
	Name = "unsmoke",
	Description = "Removes smoke from a player",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player" },
	},
	--[=[
		Removes smoke from a player.

		@param context The command context.
		@param target The player
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player)
		if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			local s = target.Character.HumanoidRootPart:FindFirstChild("AdminSmoke")
			if s then
				s:Destroy()
				return `Removed smoke from {target.Name}`
			end
			return `{target.Name} does not have smoke`
		end
		context:Error(`Could not remove smoke from {target.Name}`)
	end,
}
