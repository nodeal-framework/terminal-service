return {
	Name = "addrole",
	Description = "Gives a player a role, saved to their profile unless Temp",
	Permission = "Owner",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player to promote" },
		{ Name = "Role", Type = "Role", Description = "The role to give" },
		{ Name = "Temp", Type = "boolean", Description = "Only until they leave", Default = false, Optional = true }
	},
	Run = function(context, target: Player, role: any, temp: boolean)
		local auth = context.Terminal.AuthorizationService

		-- Nobody hands out more than they hold. No executor means the server itself.
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
	end
}
