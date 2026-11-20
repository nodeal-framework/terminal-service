return {
	Name = "setteam",
	Permission = "Admin",
	Description = "Assigns a player to a Team. Uses the team type with custom UI for selection",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
		{ Name = "Team", Type = "Team", Description = "Team to assign" }
	},
	Run = function(context, target, team)
		target.Team = team
		return `Set {target.Name}'s team to {team.Name}`
	end
}
