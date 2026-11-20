return {
	Name = "history",
	Permission = "Moderator", -- shows every player's commands, staff ones included
	Aliases = { "hist" },
	Description = "Shows recent command history",
	Args = {
		{ Name = "Count", Type = "number", Description = "How many entries to show", Default = 20, Optional = true }
	},
	Run = function(context, count: number)
		local entries = context.Terminal:GetHistory()
		if #entries == 0 then return "No commands executed yet." end

		local startIdx = math.max(1, #entries - math.max(0, count - 1))
		local lines = {}
		for i = startIdx, #entries do
			local e = entries[i]
			table.insert(lines, `{i}  {e.line}`)
		end
		return table.concat(lines, "\n")
	end
}
