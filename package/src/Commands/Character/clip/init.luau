return {
	Name = "clip",
	Permission = "Admin",
	Description = "Restores character collisions (opposite of noclip). Also clears the noclip persistence flag",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" }
	},
	Run = function(context, target: Player)
		local TerminalService = context.Terminal
		if not TerminalService.States then TerminalService.States = {} end
		local bucket = TerminalService.States[target.UserId] or {}
		TerminalService.States[target.UserId] = bucket
		bucket.Noclip = false
		if bucket.NoclipConn then
			bucket.NoclipConn:Disconnect()
			bucket.NoclipConn = nil
		end

		local function apply(char: Model)
			if not char then return end
			for _, part in char:GetDescendants() do
				if part:IsA("BasePart") then
					part.CanCollide = true
				end
			end
		end

		apply(target.Character)
		context.Terminal.Network:Fire(target, "Noclip", false)
		return `{target.Name}: Collision restored`
	end
}
