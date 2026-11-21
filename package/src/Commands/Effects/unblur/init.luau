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
	Implements the `unblur` command: Removes any active admin blur effect from
	Lighting.
]=]

return {
	Name = "unblur",
	Permission = "Admin",
	Description = "Removes any active admin blur effect from Lighting",
	--[=[
		Removes any active admin blur effect from Lighting.

		@param context The command context.
		@return A status message when the command succeeds.
	]=]
	Run = function(context)
		local blur = game:GetService("Lighting"):FindFirstChild("AdminBlur")
		if not blur then
			return "No active blur"
		end
		blur:Destroy()
		return "Blur removed"
	end,
}
