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
	Implements the `clip` command: Restores character collisions (opposite of
	noclip). Also clears the noclip persistence flag.
]=]

return {
	Name = "clip",
	Permission = "Admin",
	Description = "Restores character collisions (opposite of noclip). Also clears the noclip "
		.. "persistence flag",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
	},
	--[=[
		Restores character collisions (opposite of noclip). Also clears the noclip
		persistence flag.

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
		bucket.Noclip = false
		if bucket.NoclipConn then
			bucket.NoclipConn:Disconnect()
			bucket.NoclipConn = nil
		end

		--[=[
			Restores collisions on a character.

			@param char The character to inspect.
		]=]
		local function apply(char: Model)
			if not char then
				return
			end
			for _, part in char:GetDescendants() do
				if part:IsA("BasePart") then
					part.CanCollide = true
				end
			end
		end

		apply(target.Character)
		context.Terminal.Network:Fire(target, "Noclip", false)
		return `{target.Name}: Collision restored`
	end,
}
