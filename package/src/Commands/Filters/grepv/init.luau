return {
	Name = "grepv",
	Aliases = { "invert" },
	Description = "Filter stdin: keep only lines NOT containing the pattern",
	Args = {
		{ Name = "Pattern", Type = "string", Description = "Pattern to exclude" }
	},
	Run = function(context, pattern: string)
		local input = context:GetInput()
		if input == "" then return "" end

		local lower = string.lower(pattern)
		local out = {}
		for line in string.gmatch(input, "[^\n]+") do
			if not string.find(string.lower(line), lower, 1, true) then
				table.insert(out, line)
			end
		end
		return table.concat(out, "\n")
	end
}
