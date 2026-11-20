return {
	Name = "uniq",
	Description = "Remove duplicate consecutive lines from stdin",
	Run = function(context)
		local input = context:GetInput()
		if input == "" then return "" end

		local out = {}
		local last = nil
		for line in string.gmatch(input, "[^\n]+") do
			if line ~= last then
				table.insert(out, line)
				last = line
			end
		end
		return table.concat(out, "\n")
	end
}
