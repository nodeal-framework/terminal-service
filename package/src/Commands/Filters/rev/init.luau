return {
	Name = "rev",
	Aliases = { "reverse" },
	Description = "Reverse the order of stdin lines",
	Run = function(context)
		local input = context:GetInput()
		if input == "" then return "" end

		local lines = {}
		for line in string.gmatch(input, "[^\n]+") do
			table.insert(lines, line)
		end

		local n = #lines
		for i = 1, math.floor(n / 2) do
			lines[i], lines[n - i + 1] = lines[n - i + 1], lines[i]
		end

		return table.concat(lines, "\n")
	end
}
