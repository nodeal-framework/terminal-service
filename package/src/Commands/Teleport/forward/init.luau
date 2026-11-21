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
	Implements the `forward` command: Pushes the player N studs forward along
	their HumanoidRootPart LookVector.
]=]

return {
	Name = "forward",
	Aliases = { "fwd" },
	Permission = "Admin",
	Description = "Pushes the player N studs forward along their HumanoidRootPart LookVector",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
		{ Name = "Studs", Type = "number", Description = "Studs forward", Default = 10 },
	},
	--[=[
		Pushes the player N studs forward along their HumanoidRootPart LookVector.

		@param context The command context.
		@param target Player
		@param studs Studs forward
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player, studs: number)
		if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			local hrp = target.Character.HumanoidRootPart
			hrp.CFrame = hrp.CFrame + hrp.CFrame.LookVector * studs
			return `Pushed {target.Name} forward by {studs} studs`
		end
		context:Error(`Could not push {target.Name}`)
	end,
}
