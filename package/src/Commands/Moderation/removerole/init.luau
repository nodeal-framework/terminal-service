return {
	Name = "removerole",
	Description = "Takes a role from a player, from their profile too unless Temp",
	Permission = "Owner",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player to demote" },
		{ Name = "Role", Type = "Role", Description = "The role to take" },
		{ Name = "Temp", Type = "boolean", Description = "Only until they leave", Default = false, Optional = true }
	},
	Run = function(context, target: Player, role: any, temp: boolean)
		local auth = context.Terminal.AuthorizationService

		-- Nobody takes away more than they hold. No executor means the server itself.
		local executor = context.Executor
		local highest = executor and auth:GetHighestRoleAsync(executor)

		if executor and (not highest or role.Value > highest.Value) then
			context:Error(`removerole: {role.Name} is above your own role`)
			return
		end

		if not auth:RemoveRole(target, role, temp) then
			context:Error(`removerole: could not take {role.Name} from {target.Name}`)
			return
		end

		return `Took {role.Name} from {target.Name}{temp and " (until they leave)" or ""}`
	end
}
