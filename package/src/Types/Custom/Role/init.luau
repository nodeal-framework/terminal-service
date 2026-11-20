local Role = {}

function Role.Validate(text: string, executor: Player, terminal: table)
	local AuthorizationService = terminal.AuthorizationService
	local role = AuthorizationService:GetRoleByName(text)
	if not role then
		return false, `Role '{text}' is not registered`
	end
	return true
end

function Role.Transform(text: string, executor: Player, terminal: table)
	local AuthorizationService = terminal.AuthorizationService
	return AuthorizationService:GetRoleByName(text)
end

function Role.Autocomplete(text: string, executor: Player, terminal: table)
	local AuthorizationService = terminal.AuthorizationService
	local results = {}
	for _, role in AuthorizationService:GetRoles() do
		local score = terminal.FuzzyMatch(text, role.Name)
		if score > 0 then
			-- Subtract a tiny fraction based on role value so lower value (least important) gets a slightly higher score
			-- This ensures they are placed at the top of the list when scores are equal.
			local adjustedScore = score - ((role.Value or 0) * 0.0001)
			table.insert(results, { Text = role.Name, Score = adjustedScore })
		end
	end
	return results
end

return Role
