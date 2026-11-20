return {
	Name = "respawn",
	Permission = "Admin",
	Description = "Respawns a player (kills and respawns them at SpawnLocation)",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player to respawn" }
	},
	Run = function(context, target: Player)
		target:LoadCharacterAsync()
		return `Respawning {target.Name}`
	end
}
