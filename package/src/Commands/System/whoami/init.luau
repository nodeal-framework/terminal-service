--[[
    © 2026 Nodeal Package. All rights reserved.

    This source code is open-source and free for modification and use in your projects.
    However, you may not sell, sublicense, or distribute this framework (or 
    any rebranded version of it) as a standalone product.

    Any public use or redistribution of this module requires this header 
    to remain intact in the source code. For the complete license terms, 
    please visit: https://www.nodeal.dev/license
]]

--[=[
	Implements the `whoami` command: Displays info about the calling player.
]=]

return {
	Name = "whoami",
	Permission = "Any",
	Aliases = { "myinfo" },
	Description = "Displays info about the calling player",
	--[=[
		Displays info about the calling player.

		@param context The command context.
		@return A status message when the command succeeds.
	]=]
	Run = function(context)
		local p = context.Executor
		if not p then
			return "No executor context"
		end

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
				for _, r in roles do
					table.insert(names, r.Name)
				end
				table.insert(lines, `Roles: {table.concat(names, ", ")}`)
			else
				table.insert(lines, "Roles: none")
			end
		end

		return table.concat(lines, "\n")
	end,
}
