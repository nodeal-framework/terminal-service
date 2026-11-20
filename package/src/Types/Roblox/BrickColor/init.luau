local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local brickColors = {}
for i = 1, 1032 do
	local bc = BrickColor.new(i)
	if bc.Number == i then
		table.insert(brickColors, bc)
	end
end
table.sort(brickColors, function(a, b) return a.Name < b.Name end)

return {
	MaxTokens = 3,
	Validate = function(text: string, executor: Player)
		local lower = string.lower(text)
		for _, bc in ipairs(brickColors) do
			if string.lower(bc.Name) == lower then
				return true
			end
		end
		return false, "Invalid BrickColor"
	end,

	Transform = function(text: string, executor: Player)
		return BrickColor.new(text)
	end,

	Autocomplete = function(text: string, executor: Player, terminalService: any)
		local suggestions = {}
		for _, bc in ipairs(brickColors) do
			local score = terminalService.FuzzyMatch(text, bc.Name)
			if score > 0 then
				table.insert(suggestions, { Text = bc.Name, Description = "", Color = bc.Color, Score = score })
			end
		end
		return suggestions
	end
}
