local Players = game:GetService("Players")

return {
	Name = "players",
	Description = "Lists all players in the server",
	Permission = "Any",
	Args = {},
	Run = function(context)
		local names = {}
		for _, p in Players:GetPlayers() do
			table.insert(names, p.Name)
		end
		if #names == 0 then return "No players found" end
		return table.concat(names, "\n")
	end
}
