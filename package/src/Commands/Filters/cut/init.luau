return {
	Name = "cut",
	Description = "Extract a single field from each stdin line (delimiter-separated)",
	Args = {
		{ Name = "Delimiter", Type = "string", Description = "Field delimiter", Default = "," },
		{ Name = "Field", Type = "number", Description = "Field index (1-based)", Default = 1 }
	},
	Run = function(context, delim: string, field: number)
		local input = context:GetInput()
		if input == "" or field < 1 then return "" end

		local out = {}
		for line in string.gmatch(input, "[^\n]+") do
			local parts = string.split(line, delim)
			if parts[field] ~= nil then
				table.insert(out, parts[field])
			end
		end
		return table.concat(out, "\n")
	end
}
