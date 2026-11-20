return {
	Name = "shuf",
	Aliases = { "randomize", "shuffle" },
	Description = "Shuffle the order of stdin lines randomly",
	Run = function(context)
		local input = context:GetInput()
		if input == "" then return "" end

		local lines = {}
		for line in string.gmatch(input, "[^\n]+") do
			table.insert(lines, line)
		end

		for i = #lines, 2, -1 do
			local j = math.random(1, i)
			lines[i], lines[j] = lines[j], lines[i]
		end

		return table.concat(lines, "\n")
	end
}
