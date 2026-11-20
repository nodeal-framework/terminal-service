return {
	Name = "noclip",
	Permission = "Admin",
	Description = "Disables character collisions (noclip). State persists across respawns. Fires a 'Noclip' event to the client",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
		{ Name = "State", Type = "boolean", Description = "True = noclip ON, False = OFF", Default = true }
	},
	Run = function(context, target: Player, state: boolean)
		local TerminalService = context.Terminal
		if not TerminalService.States then TerminalService.States = {} end
		local bucket = TerminalService.States[target.UserId]
		if not bucket then bucket = {} end
		TerminalService.States[target.UserId] = bucket
		bucket.Noclip = state

		local function apply(char: Model)
			if not char then return end
			for _, part in char:GetDescendants() do
				if part:IsA("BasePart") then
					part.CanCollide = not state
				end
			end
		end

		apply(target.Character)

		if state then
			if bucket.NoclipConn then bucket.NoclipConn:Disconnect() end
			bucket.NoclipConn = target.CharacterAdded:Connect(function(char)
				local stored = bucket.Noclip
				if not stored then return end
				task.defer(function()
					local hrp = char:WaitForChild("HumanoidRootPart", 5)
					if hrp then
						for _, part in char:GetDescendants() do
							if part:IsA("BasePart") then
								part.CanCollide = false
							end
						end
					end
				end)
			end)
		elseif bucket.NoclipConn then
			bucket.NoclipConn:Disconnect()
			bucket.NoclipConn = nil
		end

		context.Terminal.Network:Fire(target, "Noclip", state)
		return `{target.Name}: Noclip = {tostring(state)}`
	end
}
