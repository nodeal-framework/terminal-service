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
	Implements the `paint` command: Paints a player's character BodyColors to
	the given BrickColor (R6 avatars only).
]=]

return {
	Name = "paint",
	Permission = "Admin",
	Description = "Paints a player's character BodyColors to the given BrickColor (R6 avatars only)",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
		{ Name = "Color", Type = "BrickColor", Description = "Body color" },
	},
	--[=[
		Paints a player's character BodyColors to the given BrickColor (R6 avatars
		only).

		@param context The command context.
		@param target Player
		@param color Body color
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player, color: BrickColor)
		local char = target.Character
		if not char then
			context:Error(`{target.Name} has no character`)
			return
		end
		local bodyColors = char:FindFirstChild("Body Colors")
		if not bodyColors then
			context:Error(`{target.Name} has no Body Colors (R15 avatars not supported by paint)`)
			return
		end
		for _, sub in bodyColors:GetChildren() do
			if sub:IsA("Color3Value") then
				sub.Value = color.Color
			end
		end
		return `{target.Name}'s body painted to {color.Name}`
	end,
}
