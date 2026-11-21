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
	Argument type `type`: validates, transforms and autocompletes input typed
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
		if terminalService:GetTypes()[text] then
			return true
		end
		return false, "Invalid Terminal Type"
	end,

	--[=[
		Converts validated text into the value the command receives.

		@param text The validated text.
		@param executor The player running the command.
		@param terminalService The terminal service.
		@return The typed value.
	]=]
	Transform = function(text: string, executor: Player, terminalService: any)
		return text
	end,

	--[=[
		Returns completion candidates for partially typed text.

		@param text The text typed so far.
		@param executor The player running the command.
		@param terminalService The terminal service.
		@return The list of suggestions.
	]=]
	Autocomplete = function(text: string, executor: Player, terminalService: any)
		local suggestions = {}
		for tName, _ in terminalService:GetTypes() do
			local score = terminalService.FuzzyMatch(text, tName)
			if score > 0 then
				table.insert(suggestions, { Text = tName, Score = score })
			end
		end

		return suggestions
	end,
}
