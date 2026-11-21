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
	Argument type `boolean`: validates, transforms and autocompletes input typed
	into the terminal.
]=]

local truthy = { ["true"] = true, ["yes"] = true, ["1"] = true, ["y"] = true }
local falsy = { ["false"] = true, ["no"] = true, ["0"] = true, ["n"] = true }

return {
	--[=[
		Validates raw terminal input for this type.

		@param text The text typed by the player.
		@param executor The player running the command.
		@return True when the text is valid, plus an error message otherwise.
	]=]
	Validate = function(text: string, executor: Player)
		local lower = string.lower(text)
		if truthy[lower] or falsy[lower] then
			return true
		end
		return false, `'{text}' is not a valid boolean (expected true/false, yes/no, 1/0)`
	end,

	--[=[
		Converts validated text into the value the command receives.

		@param text The validated text.
		@param executor The player running the command.
		@return The typed value.
	]=]
	Transform = function(text: string, executor: Player)
		local lower = string.lower(text)
		return truthy[lower] == true
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
		for _, opt in { "yes", "no" } do
			local score = terminalService.FuzzyMatch(text, opt)
			if score > 0 then
				table.insert(results, { Text = opt, Score = score })
			end
		end
		return results
	end,
}
