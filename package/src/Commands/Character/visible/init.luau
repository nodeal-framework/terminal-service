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
	Implements the `visible` command: Restores visibility on a player's
	character (opposite of invisible). Clears the invisible persistence flag.
]=]

return {
	Name = "visible",
	Aliases = { "vis" },
	Permission = "Admin",
	Description = "Restores visibility on a player's character (opposite of invisible). Clears the "
		.. "invisible persistence flag",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
	},
	--[=[
		Restores visibility on a player's character (opposite of invisible). Clears
		the invisible persistence flag.

		@param context The command context.
		@param target Player
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player)
		local TerminalService = context.Terminal
		if not TerminalService.States then
			TerminalService.States = {}
		end
		local bucket = TerminalService.States[target.UserId] or {}
		TerminalService.States[target.UserId] = bucket
		bucket.Invisible = false
		if bucket.InvisibleConn then
			bucket.InvisibleConn:Disconnect()
			bucket.InvisibleConn = nil
		end

		--[=[
			Restores transparency on a character.

			@param char The character to inspect.
		]=]
		local function apply(char: Model)
			if not char then
				return
			end
			for _, part in char:GetDescendants() do
				if part:IsA("BasePart") or part:IsA("Decal") or part:IsA("Texture") then
					part.Transparency = 0
				end
			end
		end

		apply(target.Character)
		context.Terminal.Network:Fire(target, "Invisible", false)
		return `{target.Name}: Visible restored`
	end,
}
