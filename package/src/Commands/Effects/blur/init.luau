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
	Implements the `blur` command: Adds an Admin BlurEffect to Lighting for
	ambiance.
]=]

return {
	Name = "blur",
	Permission = "Admin",
	Description = "Adds an Admin BlurEffect to Lighting for ambiance",
	Args = {
		{ Name = "Size", Type = "number", Description = "Blur size (0-56)", Default = 20 },
	},
	--[=[
		Adds an Admin BlurEffect to Lighting for ambiance.

		@param context The command context.
		@param size Blur size (0-56)
		@return A status message when the command succeeds.
	]=]
	Run = function(context, size: number)
		local Lighting = game:GetService("Lighting")
		local existing = Lighting:FindFirstChild("AdminBlur")
		if existing then
			existing:Destroy()
		end
		local blur = Instance.new("BlurEffect")
		blur.Name = "AdminBlur"
		blur.Size = size
		blur.Parent = Lighting
		return `Blur effect applied (size {size})`
	end,
}
