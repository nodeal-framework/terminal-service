return {
	Name = "sort",
	Permission = "Any",
	Description = "Sort lines of stdin alphabetically (case-insensitive)",
	Args = {
		{ Name = "Reverse", Type = "boolean", Description = "Reverse sort order", Default = false, Optional = true }
	},
	Run = function(context, reverse: boolean)
		local input = context:GetInput()
		if input == "" then return "" end

		local lines = {}
		for line in string.gmatch(input, "[^\n]+") do
			table.insert(lines, line)
		end

		table.sort(lines, function(a, b)
			local la, lb = string.lower(a), string.lower(b)
			if reverse then return la > lb else return la < lb end
		end)

		return table.concat(lines, "\n")
	end
}
