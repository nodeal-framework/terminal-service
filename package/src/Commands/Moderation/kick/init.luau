return {
	Name = "kick",
	Description = "Kicks a player from the server",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player to kick" },
		{ Name = "Reason", Type = "string", Description = "Reason for the kick", Default = "No reason" }
	},
	Run = function(context, target: Player, reason: string)
		target:Kick(reason)
		return `Kicked {target.Name} for: {reason}`
	end
}