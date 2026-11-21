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
	Implements the `addrole` command: Gives a player a role, saved to their
	profile unless Temp.
]=]

return {
	Name = "addrole",
	Description = "Gives a player a role, saved to their profile unless Temp",
	Permission = "Owner",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player to promote" },
		{ Name = "Role", Type = "Role", Description = "The role to give" },
		{
			Name = "Temp",
			Type = "boolean",
			Description = "Only until they leave",
			Default = false,
			Optional = true,
		},
	},
	--[=[
		Gives a player a role, saved to their profile unless Temp.

		@param context The command context.
		@param target The player to promote
		@param role The role to give
		@param temp Only until they leave
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player, role: any, temp: boolean)
		local auth = context.Terminal.AuthorizationService

		local executor = context.Executor
		local highest = executor and auth:GetHighestRoleAsync(executor)

		if executor and (not highest or role.Value > highest.Value) then
			context:Error(`addrole: {role.Name} is above your own role`)
			return
		end

		if not auth:AddRole(target, role, temp) then
			context:Error(`addrole: could not give {role.Name} to {target.Name}`)
			return
		end

		return `Gave {role.Name} to {target.Name}{temp and " (until they leave)" or ""}`
	end,
}
