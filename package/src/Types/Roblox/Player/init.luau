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
	Argument type `Player`: validates, transforms and autocompletes input typed
	into the terminal.
]=]

local Players = game:GetService("Players")

--[=[
	Returns players whose name or display name starts with the text.

	@param text The text to inspect.

	@return The resulting list.
]=]
local function getMatchingPlayers(text: string): { Player }
	local lower = string.lower(text)
	local matches = {}
	for _, p in Players:GetPlayers() do
		local nameMatch = string.sub(string.lower(p.Name), 1, #lower) == lower
		local displayMatch = string.sub(string.lower(p.DisplayName), 1, #lower) == lower
		local idMatch = string.sub(tostring(p.UserId), 1, #text) == text

		if nameMatch or displayMatch or idMatch then
			table.insert(matches, p)
		end
	end
	return matches
end

return {
	--[=[
		Validates raw terminal input for this type.

		@param text The text typed by the player.
		@param executor The player running the command.
		@return True when the text is valid, plus an error message otherwise.
	]=]
	Validate = function(text: string, executor: Player)
		local lower = string.lower(text)
		if lower == "." or lower == "me" or lower == "myself" then
			return true
		end
		if lower == "*" or lower == "all" then
			return true
		end
		if lower == "**" or lower == "others" then
			return true
		end
		if lower == "?" or lower == "random" then
			return true
		end

		for _, name in string.split(text, ",") do
			name = string.match(name, "^%s*(.-)%s*$")
			if name ~= "" then
				local matches = getMatchingPlayers(name)
				if #matches == 0 then
					return false, `Player '{name}' not found`
				end
			end
		end

		return true
	end,

	--[=[
		Converts validated text into the value the command receives.

		@param text The validated text.
		@param executor The player running the command.
		@return The typed value.
	]=]
	Transform = function(text: string, executor: Player)
		local lower = string.lower(text)
		if lower == "." or lower == "me" or lower == "myself" then
			return executor
		elseif lower == "*" or lower == "all" then
			return { __isMultiValue = true, Values = Players:GetPlayers() }
		elseif lower == "**" or lower == "others" then
			local others = {}
			for _, p in Players:GetPlayers() do
				if p ~= executor then
					table.insert(others, p)
				end
			end
			return { __isMultiValue = true, Values = others }
		elseif lower == "?" or lower == "random" then
			local all = Players:GetPlayers()
			if #all > 0 then
				return all[math.random(1, #all)]
			end
			return executor
		end

		local targets = {}
		local added = {}
		for _, name in string.split(text, ",") do
			name = string.match(name, "^%s*(.-)%s*$")
			if name ~= "" then
				local matches = getMatchingPlayers(name)
				for _, p in matches do
					if not added[p] then
						added[p] = true
						table.insert(targets, p)
					end
				end
			end
		end

		if #targets == 1 then
			return targets[1]
		else
			return { __isMultiValue = true, Values = targets }
		end
	end,

	--[=[
		Returns completion candidates for partially typed text.

		@param text The text typed so far.
		@param executor The player running the command.
		@param terminalService The terminal service.
		@return The list of suggestions.
	]=]
	Autocomplete = function(text: string, executor: Player, terminalService: any)
		local specialTags = {
			{ Text = "me", Description = "Yourself" },
			{ Text = "*", Description = "All players" },
			{ Text = "**", Description = "All other players" },
			{ Text = "?", Description = "A random player" },
		}

		local suggestions = {}
		local lastCommaIdx = string.find(text, ",[^,]*$")
		local prefix = ""
		local currentQuery = text

		if lastCommaIdx then
			prefix = string.sub(text, 1, lastCommaIdx)
			currentQuery = string.sub(text, lastCommaIdx + 1)
			currentQuery = string.match(currentQuery, "^%s*(.-)$")
		end

		for _, tag in specialTags do
			local score = terminalService.FuzzyMatch(currentQuery, tag.Text)
			if score > 0 then
				if currentQuery == "" then
					score = 1000
				end
				table.insert(suggestions, {
					Text = prefix .. tag.Text,
					Description = tag.Description,
					Score = score,
				})
			end
		end

		for _, p in Players:GetPlayers() do
			local score = terminalService.FuzzyMatch(currentQuery, p.Name)
			local scoreDisplay = terminalService.FuzzyMatch(currentQuery, p.DisplayName)
			local scoreId = terminalService.FuzzyMatch(currentQuery, tostring(p.UserId))
			local bestScore = math.max(score, scoreDisplay, scoreId)

			if bestScore > 0 then
				table.insert(suggestions, {
					Text = prefix .. p.Name,
					DisplayText = prefix .. p.DisplayName,
					Description = string.format("%s (%d)", p.Name, p.UserId),
					Icon = "rbxthumb://type=AvatarHeadShot&id=" .. p.UserId .. "&w=150&h=150",
					Score = bestScore,
				})
			end
		end

		return suggestions
	end,
}
