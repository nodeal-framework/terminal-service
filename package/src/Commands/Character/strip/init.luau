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
	Implements the `strip` command: Removes all equipped tools, accessories,
	shirts, pants and shirt graphics from a player.
]=]

return {
	Name = "strip",
	Permission = "Admin",
	Description = "Removes all equipped tools, accessories, shirts, pants and shirt graphics from a "
		.. "player",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
	},
	--[=[
		Removes all equipped tools, accessories, shirts, pants and shirt graphics
		from a player.

		@param context The command context.
		@param target Player
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player)
		if not target.Character then
			context:Error(`{target.Name} has no character`)
			return
		end
		local removed = 0
		for _, item in target.Character:GetChildren() do
			if
				item:IsA("Tool")
				or item:IsA("Accessory")
				or item:IsA("Shirt")
				or item:IsA("Pants")
				or item:IsA("ShirtGraphic")
			then
				item:Destroy()
				removed += 1
			end
		end
		if target:FindFirstChild("Backpack") then
			for _, item in target.Backpack:GetChildren() do
				if item:IsA("Tool") then
					item:Destroy()
					removed += 1
				end
			end
		end
		return `Stripped {removed} item(s) from {target.Name}`
	end,
}
