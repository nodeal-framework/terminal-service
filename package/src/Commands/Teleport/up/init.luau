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
	Implements the `up` command: Raises a player by N studs on the Y axis.
]=]

return {
	Name = "up",
	Permission = "Admin",
	Description = "Raises a player by N studs on the Y axis",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
		{ Name = "Studs", Type = "number", Description = "Studs to raise", Default = 10 },
	},
	--[=[
		Raises a player by N studs on the Y axis.

		@param context The command context.
		@param target Player
		@param studs Studs to raise
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player, studs: number)
		if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			target.Character.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame
				+ Vector3.new(0, studs, 0)
			return `Raised {target.Name} by {studs} studs`
		end
		context:Error(`Could not raise {target.Name}`)
	end,
}
