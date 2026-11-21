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
	Implements the `cleardebris` command: Removes loose non-anchored Parts from
	the workspace root (debris cleanup).
]=]

return {
	Name = "cleardebris",
	Aliases = { "clean" },
	Permission = "Admin",
	Description = "Removes loose non-anchored Parts from the workspace root (debris cleanup)",
	--[=[
		Removes loose non-anchored Parts from the workspace root (debris cleanup).

		@param context The command context.
		@return A status message when the command succeeds.
	]=]
	Run = function(context)
		local removed = 0
		for _, child in workspace:GetChildren() do
			if child:IsA("BasePart") and not child.Anchored then
				child:Destroy()
				removed += 1
			end
		end
		if removed == 0 then
			return "No debris found in workspace root"
		end
		return `Cleared {removed} debris`
	end,
}
