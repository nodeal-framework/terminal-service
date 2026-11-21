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
	Implements the `highlight` command: Applies a Highlight instance to a
	player's character.
]=]

return {
	Name = "highlight",
	Permission = "Admin",
	Description = "Applies a Highlight instance to a player's character",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
		{
			Name = "Color",
			Type = "Color3",
			Description = "Highlight color",
			Default = Color3.fromRGB(255, 255, 0),
			Optional = true,
		},
	},
	--[=[
		Applies a Highlight instance to a player's character.

		@param context The command context.
		@param target Player
		@param color Highlight color
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player, color: Color3)
		local char = target.Character
		if not char then
			context:Error(`{target.Name} has no character`)
			return
		end
		local existing = char:FindFirstChild("AdminHighlight")
		if existing then
			existing:Destroy()
		end

		local hl = Instance.new("Highlight")
		hl.Name = "AdminHighlight"
		hl.FillColor = color
		hl.OutlineColor = color
		hl.Parent = char
		return `Highlight applied to {target.Name}`
	end,
}
