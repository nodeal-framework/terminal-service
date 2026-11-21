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
	Implements the `coords` command: Shows the executor's current character
	coordinates.
]=]

return {
	Name = "coords",
	Permission = "Any",
	Aliases = { "pos", "position", "whereami" },
	Description = "Shows the executor's current character coordinates",
	--[=[
		Shows the executor's current character coordinates.

		@param context The command context.
		@return A status message when the command succeeds.
	]=]
	Run = function(context)
		local p = context.Executor
		if not p or not p.Character or not p.Character:FindFirstChild("HumanoidRootPart") then
			return "No character to locate"
		end
		local position = p.Character.HumanoidRootPart.Position
		return string.format("Position: X=%.2f Y=%.2f Z=%.2f", position.X, position.Y, position.Z)
	end,
}
