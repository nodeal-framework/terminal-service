local Teams = game:GetService("Teams")

local function findTeam(text: string): Team?
	local lower = string.lower(text)
	for _, t in Teams:GetTeams() do
		if t.Name:lower() == lower then
			return t
		end
	end
	return nil
end

return {
	Validate = function(text: string, executor: Player)
		if findTeam(text) then return true end
		return false, `Team '{text}' not found`
	end,

	Transform = function(text: string, executor: Player)
		return findTeam(text)
	end,

	Autocomplete = function(text: string, executor: Player, terminalService: any)
		local results = {}
		for _, t in Teams:GetTeams() do
			local score = terminalService.FuzzyMatch(text, t.Name)
			if score > 0 then
				table.insert(results, {
					Text = t.Name,
					Description = t.TeamColor.Name,
					Color = t.TeamColor.Color,
					Score = score,
				})
			end
		end
		return results
	end,
}
