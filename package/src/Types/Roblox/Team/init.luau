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
	Argument type `Team`: validates, transforms and autocompletes input typed
	into the terminal.
]=]

local Teams = game:GetService("Teams")

--[=[
	Finds a team by case-insensitive name.

	@param text The text to inspect.

	@return The result, or nil.
]=]
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
	--[=[
		Validates raw terminal input for this type.

		@param text The text typed by the player.
		@param executor The player running the command.
		@return True when the text is valid, plus an error message otherwise.
	]=]
	Validate = function(text: string, executor: Player)
		if findTeam(text) then
			return true
		end
		return false, `Team '{text}' not found`
	end,

	--[=[
		Converts validated text into the value the command receives.

		@param text The validated text.
		@param executor The player running the command.
		@return The typed value.
	]=]
	Transform = function(text: string, executor: Player)
		return findTeam(text)
	end,

	--[=[
		Returns completion candidates for partially typed text.

		@param text The text typed so far.
		@param executor The player running the command.
		@param terminalService The terminal service.
		@return The list of suggestions.
	]=]
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
