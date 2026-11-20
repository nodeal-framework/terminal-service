return {
	Name = "visible",
	Aliases = { "vis" },
	Permission = "Admin",
	Description = "Restores visibility on a player's character (opposite of invisible). Clears the invisible persistence flag",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" }
	},
	Run = function(context, target: Player)
		local TerminalService = context.Terminal
		if not TerminalService.States then TerminalService.States = {} end
		local bucket = TerminalService.States[target.UserId] or {}
		TerminalService.States[target.UserId] = bucket
		bucket.Invisible = false
		if bucket.InvisibleConn then
			bucket.InvisibleConn:Disconnect()
			bucket.InvisibleConn = nil
		end

		local function apply(char: Model)
			if not char then return end
			for _, part in char:GetDescendants() do
				if part:IsA("BasePart") or part:IsA("Decal") or part:IsA("Texture") then
					part.Transparency = 0
				end
			end
		end

		apply(target.Character)
		context.Terminal.Network:Fire(target, "Invisible", false)
		return `{target.Name}: Visible restored`
	end
}
