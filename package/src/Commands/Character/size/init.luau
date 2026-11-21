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
	Implements the `size` command: Scales a player's character (body
	depth/height/width + head). Requires R15 avatars.
]=]

return {
	Name = "size",
	Permission = "Admin",
	Description = "Scales a player's character (body depth/height/width + head). Requires R15 avatars",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
		{
			Name = "Multiplier",
			Type = "number",
			Description = "Scale multiplier (positive)",
			Default = 1,
		},
	},
	--[=[
		Scales a player's character (body depth/height/width + head). Requires R15
		avatars.

		@param context The command context.
		@param target Player
		@param multiplier The multiplier to apply.
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target, multiplier)
		local char = target.Character
		if not char then
			context:Error(`{target.Name} has no character`)
			return
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then
			context:Error(`{target.Name} has no Humanoid`)
			return
		end
		if multiplier <= 0 then
			context:Error("Scale must be positive")
			return
		end
		local scaleFound = false
		for _, name in { "BodyDepthScale", "BodyHeightScale", "BodyWidthScale", "HeadScale" } do
			local number = hum:FindFirstChild(name)
			if number and number:IsA("NumberValue") then
				number.Value = multiplier
				scaleFound = true
			end
		end
		if not scaleFound then
			context:Error(`{target.Name} has no scale NumberValues (size requires R15 avatars)`)
			return
		end
		return `Scaled {target.Name} to {multiplier}x`
	end,
}
