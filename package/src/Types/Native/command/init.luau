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
	Argument type `command`: validates, transforms and autocompletes input typed
	into the terminal.
]=]

return {
	--[=[
		Validates raw terminal input for this type.

		@param text The text typed by the player.
		@param executor The player running the command.
		@param terminalService The terminal service.
		@return True when the text is valid, plus an error message otherwise.
	]=]
	Validate = function(text: string, executor: Player, terminalService: any)
		local command = terminalService:GetCommand(string.lower(text))
		if command then
			return true
		end
		return false, `Command '{text}' not found`
	end,

	--[=[
		Converts validated text into the value the command receives.

		@param text The validated text.
		@param executor The player running the command.
		@param terminalService The terminal service.
		@return The typed value.
	]=]
	Transform = function(text: string, executor: Player, terminalService: any)
		return string.lower(text)
	end,

	--[=[
		Returns completion candidates for partially typed text.

		@param text The text typed so far.
		@param executor The player running the command.
		@param terminalService The terminal service.
		@return The list of suggestions.
	]=]
	Autocomplete = function(text: string, executor: Player, terminalService: any)
		local list = {}
		local prefix = string.lower(text)

		local commands = terminalService:GetCommands()
		for name, command in pairs(commands) do
			local score = terminalService.FuzzyMatch(prefix, name)
			if score > 0 then
				table.insert(list, {
					Text = name,
					Description = command.Description or "",
					Score = score,
				})
			end

			if command.Aliases then
				for _, alias in ipairs(command.Aliases) do
					local aliasScore = terminalService.FuzzyMatch(prefix, alias)
					if aliasScore > 0 then
						table.insert(list, {
							Text = alias,
							Description = `Alias for {name}`,
							Score = aliasScore,
						})
					end
				end
			end
		end

		table.sort(list, function(a, b)
			return (a.Score or 0) > (b.Score or 0)
		end)
		return list
	end,
}
