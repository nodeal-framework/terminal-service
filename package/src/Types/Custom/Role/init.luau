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
	Argument type `Role`: resolves a role name against the authorization service.

	Used by role management commands so an operator types a role name instead of an id.
]=]

local Role = {}

--[=[
	Validates raw terminal input for this type.

	@param text The text typed by the player.
	@param executor The player running the command.
	@param terminal The terminal service.
	@return True when the text is valid, plus an error message otherwise.
]=]
function Role.Validate(text: string, executor: Player, terminal: table)
	local AuthorizationService = terminal.AuthorizationService
	local role = AuthorizationService:GetRoleByName(text)
	if not role then
		return false, `Role '{text}' is not registered`
	end
	return true
end

--[=[
	Converts validated text into the value the command receives.

	@param text The validated text.
	@param executor The player running the command.
	@param terminal The terminal service.
	@return The typed value.
]=]
function Role.Transform(text: string, executor: Player, terminal: table)
	local AuthorizationService = terminal.AuthorizationService
	return AuthorizationService:GetRoleByName(text)
end

--[=[
	Returns completion candidates for partially typed text.

	@param text The text typed so far.
	@param executor The player running the command.
	@param terminal The terminal service.
	@return The list of suggestions.
]=]
function Role.Autocomplete(text: string, executor: Player, terminal: table)
	local AuthorizationService = terminal.AuthorizationService
	local results = {}
	for _, role in AuthorizationService:GetRoles() do
		local score = terminal.FuzzyMatch(text, role.Name)
		if score > 0 then
			-- Subtract a tiny fraction based on role value so lower value (least
			-- important) gets a slightly higher score, placing them at the top of
			-- the list when scores are equal.
			local adjustedScore = score - ((role.Value or 0) * 0.0001)
			table.insert(results, { Text = role.Name, Score = adjustedScore })
		end
	end
	return results
end

return Role
