return {
	Name = "head",
	Permission = "Any",
	Description = "Take the first N lines of stdin",
	Args = {
		{ Name = "Count", Type = "number", Description = "Number of lines", Default = 5 }
	},
	Run = function(context, count: number)
		local input = context:GetInput()
		if input == "" or count <= 0 then return "" end

		local out = {}
		local idx = 0
		for line in string.gmatch(input, "[^\n]+") do
			if idx >= count then break end
			table.insert(out, line)
			idx += 1
		end
		return table.concat(out, "\n")
	end
}
