return {
	Name = "whoami",
	Aliases = { "myinfo" },
	Description = "Displays info about the calling player",
	Run = function(context)
		local p = context.Executor
		if not p then return "No executor context" end

		local lines = {
			`Name: {p.Name}`,
			`DisplayName: {p.DisplayName}`,
			`UserId: {p.UserId}`,
			`AccountAge: {p.AccountAge} days`,
		}

		local auth = context.Terminal.AuthorizationService
		if auth then
			local roles = auth:GetPlayerRoles(p)
			if #roles > 0 then
				local names = {}
				for _, r in roles do table.insert(names, r.Name) end
				table.insert(lines, `Roles: {table.concat(names, ", ")}`)
			else
				table.insert(lines, "Roles: none")
			end
		end

		return table.concat(lines, "\n")
	end
}
