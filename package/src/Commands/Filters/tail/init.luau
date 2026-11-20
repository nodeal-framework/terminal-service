return {
	Name = "tail",
	Permission = "Any",
	Description = "Take the last N lines of stdin",
	Args = {
		{ Name = "Count", Type = "number", Description = "Number of lines", Default = 5 }
	},
	Run = function(context, count: number)
		local input = context:GetInput()
		if input == "" or count <= 0 then return "" end

		local lines = {}
		for line in string.gmatch(input, "[^\n]+") do
			table.insert(lines, line)
		end

		local start = math.max(1, #lines - count + 1)
		local out = {}
		for i = start, #lines do
			table.insert(out, lines[i])
		end
		return table.concat(out, "\n")
	end
}
