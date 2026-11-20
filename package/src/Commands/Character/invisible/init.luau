return {
	Name = "invisible",
	Aliases = { "invis" },
	Permission = "Admin",
	Description = "Toggles player character visibility. State persists across respawns. Fires 'Invisible' event to the client",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
		{ Name = "State", Type = "boolean", Description = "True = hide, False = show", Default = true }
	},
	Run = function(context, target: Player, state: boolean)
		local TerminalService = context.Terminal
		if not TerminalService.States then TerminalService.States = {} end
		local bucket = TerminalService.States[target.UserId] or {}
		TerminalService.States[target.UserId] = bucket
		bucket.Invisible = state

		local function apply(char: Model)
			if not char then return end
			for _, part in char:GetDescendants() do
				if part:IsA("BasePart") or part:IsA("Decal") or part:IsA("Texture") then
					part.Transparency = state and 1 or 0
				end
			end
		end

		apply(target.Character)

		if state then
			if bucket.InvisibleConn then bucket.InvisibleConn:Disconnect() end
			bucket.InvisibleConn = target.CharacterAdded:Connect(function(char)
				local stored = bucket.Invisible
				if not stored then return end
				task.defer(function()
					for _, part in char:GetDescendants() do
						if part:IsA("BasePart") or part:IsA("Decal") or part:IsA("Texture") then
							part.Transparency = 1
						end
					end
				end)
			end)
		elseif bucket.InvisibleConn then
			bucket.InvisibleConn:Disconnect()
			bucket.InvisibleConn = nil
		end

		context.Terminal.Network:Fire(target, "Invisible", state)
		return `{target.Name}: Invisible = {tostring(state)}`
	end
}
