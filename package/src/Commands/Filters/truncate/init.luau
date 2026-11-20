return {
	Name = "truncate",
	Aliases = { "trunc", "limit" },
	Description = "Limit stdin to at most N lines",
	Args = {
		{ Name = "MaxLines", Type = "number", Description = "Maximum lines to keep", Default = 10 }
	},
	Run = function(context, max: number)
		local input = context:GetInput()
		if input == "" or max <= 0 then return "" end

		local out = {}
		local idx = 0
		for line in string.gmatch(input, "[^\n]+") do
			if idx >= max then break end
			table.insert(out, line)
			idx += 1
		end
		return table.concat(out, "\n")
	end
}
