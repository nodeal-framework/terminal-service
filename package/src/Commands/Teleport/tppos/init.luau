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
	Implements the `tppos` command: Teleports a player to specific coordinates
	(X, Y, Z).
]=]

return {
	Name = "tppos",
	Permission = "Admin",
	Description = "Teleports a player to specific coordinates (X, Y, Z)",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
		{ Name = "Position", Type = "Vector3", Description = "Target coordinates" },
	},
	--[=[
		Teleports a player to specific coordinates (X, Y, Z).

		@param context The command context.
		@param target Player
		@param position Target coordinates
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player, position: Vector3)
		if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			context.Terminal:SavePos(target)
			target.Character.HumanoidRootPart.CFrame = CFrame.new(position)
			return `Teleported {target.Name} to {position.X}, {position.Y}, {position.Z}`
		end
		context:Error(`Could not teleport {target.Name}`)
	end,
}
