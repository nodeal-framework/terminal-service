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
	Argument type `BrickColor`: validates, transforms and autocompletes input
	typed into the terminal.
]=]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local brickColors = {}
for i = 1, 1032 do
	local bc = BrickColor.new(i)
	if bc.Number == i then
		table.insert(brickColors, bc)
	end
end
table.sort(brickColors, function(a, b)
	return a.Name < b.Name
end)

return {
	MaxTokens = 3,
	--[=[
		Validates raw terminal input for this type.

		@param text The text typed by the player.
		@param executor The player running the command.
		@return True when the text is valid, plus an error message otherwise.
	]=]
	Validate = function(text: string, executor: Player)
		local lower = string.lower(text)
		for _, bc in ipairs(brickColors) do
			if string.lower(bc.Name) == lower then
				return true
			end
		end
		return false, "Invalid BrickColor"
	end,

	--[=[
		Converts validated text into the value the command receives.

		@param text The validated text.
		@param executor The player running the command.
		@return The typed value.
	]=]
	Transform = function(text: string, executor: Player)
		return BrickColor.new(text)
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
		for _, bc in ipairs(brickColors) do
			local score = terminalService.FuzzyMatch(text, bc.Name)
			if score > 0 then
				table.insert(
					suggestions,
					{ Text = bc.Name, Description = "", Color = bc.Color, Score = score }
				)
			end
		end
		return suggestions
	end,
}
