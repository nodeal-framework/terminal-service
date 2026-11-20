return {
	Validate = function(text: string, executor: Player, terminalService: any)
		if terminalService:GetTypes()[text] then
			return true
		end
		return false, "Invalid Terminal Type"
	end,

	Transform = function(text: string, executor: Player, terminalService: any)
		return text
	end,

	Autocomplete = function(text: string, executor: Player, terminalService: any)
		local suggestions = {}
		for tName, _ in terminalService:GetTypes() do
			local score = terminalService.FuzzyMatch(text, tName)
			if score > 0 then
				table.insert(suggestions, { Text = tName, Score = score })
			end
		end

		return suggestions
	end
}
