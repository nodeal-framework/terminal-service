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
	Implements the `admins` command: Lists online players with at least the
	given role value.
]=]

local Players = game:GetService("Players")

return {
	Name = "admins",
	Permission = "Any",
	Aliases = { "staff" },
	Description = "Lists online players with at least the given role value",
	Args = {
		{
			Name = "MinValue",
			Type = "number",
			Description = "Minimum role value to include",
			Default = 1,
			Optional = true,
		},
	},
	--[=[
		Lists online players with at least the given role value.

		@param context The command context.
		@param minValue Minimum role value to include
		@return A status message when the command succeeds.
	]=]
	Run = function(context, minValue: number)
		local auth = context.Terminal.AuthorizationService
		if not auth then
			return "AuthorizationService unavailable"
		end

		local names = {}
		for _, p in Players:GetPlayers() do
			if auth:HasPermission(p, minValue) then
				table.insert(names, p.Name)
			end
		end

		if #names == 0 then
			return "No admins online"
		end
		return table.concat(names, "\n")
	end,
}
