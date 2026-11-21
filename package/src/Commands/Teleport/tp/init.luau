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
	Implements the `tp` command: Teleports Subject to Destination's position.
]=]

return {
	Name = "tp",
	Permission = "Admin",
	Description = "Teleports Subject to Destination's position",
	Args = {
		{ Name = "Subject", Type = "Player", Description = "Player to teleport" },
		{ Name = "Destination", Type = "Player", Description = "Destination player" },
	},
	--[=[
		Teleports Subject to Destination's position.

		@param context The command context.
		@param subject Player to teleport
		@param destination Destination player
		@return A status message when the command succeeds.
	]=]
	Run = function(context, subject: Player, destination: Player)
		if
			subject.Character
			and subject.Character:FindFirstChild("HumanoidRootPart")
			and destination.Character
			and destination.Character:FindFirstChild("HumanoidRootPart")
		then
			context.Terminal:SavePos(subject)
			subject.Character.HumanoidRootPart.CFrame = destination.Character.HumanoidRootPart.CFrame
				* CFrame.new(0, 0, -3)
			return `Teleported {subject.Name} to {destination.Name}`
		end
		context:Error("Could not teleport (missing character or HumanoidRootPart)")
	end,
}
