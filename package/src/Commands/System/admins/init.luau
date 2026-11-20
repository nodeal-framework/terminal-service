local Players = game:GetService("Players")

return {
	Name = "admins",
	Permission = "Any",
	Aliases = { "staff" },
	Description = "Lists online players with at least the given role value",
	Args = {
		{ Name = "MinValue", Type = "number", Description = "Minimum role value to include", Default = 1, Optional = true }
	},
	Run = function(context, minValue: number)
		local auth = context.Terminal.AuthorizationService
		if not auth then return "AuthorizationService unavailable" end

		local names = {}
		for _, p in Players:GetPlayers() do
			if auth:HasPermission(p, minValue) then
				table.insert(names, p.Name)
			end
		end

		if #names == 0 then return "No admins online" end
		return table.concat(names, "\n")
	end
}
