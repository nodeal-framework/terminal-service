return {
	Validate = function(text: string, executor: Player, terminalService: any)
		local cmd = terminalService:GetCommand(string.lower(text))
		if cmd then return true end
		return false, `Command '{text}' not found`
	end,

	Transform = function(text: string, executor: Player, terminalService: any)
		return string.lower(text)
	end,

	Autocomplete = function(text: string, executor: Player, terminalService: any)
		local list = {}
		local prefix = string.lower(text)

		local commands = terminalService:GetCommands()
		for name, cmd in pairs(commands) do
			local score = terminalService.FuzzyMatch(prefix, name)
			if score > 0 then
				table.insert(list, {
					Text = name,
					Description = cmd.Description or "",
					Score = score
				})
			end

			if cmd.Aliases then
				for _, alias in ipairs(cmd.Aliases) do
					local aliasScore = terminalService.FuzzyMatch(prefix, alias)
					if aliasScore > 0 then
						table.insert(list, {
							Text = alias,
							Description = `Alias for {name}`,
							Score = aliasScore
						})
					end
				end
			end
		end

		table.sort(list, function(a, b) return (a.Score or 0) > (b.Score or 0) end)
		return list
	end
}
