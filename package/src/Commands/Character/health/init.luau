return {
	Name = "health",
	Permission = "Admin",
	Description = "Sets a player's current Health",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
		{ Name = "Health", Type = "number", Description = "Health value (cannot exceed MaxHealth unless god)" }
	},
	Run = function(context, target, health)
		if not target.Character or not target.Character:FindFirstChildOfClass("Humanoid") then
			context:Error(`{target.Name} has no Humanoid`)
			return
		end
		target.Character.Humanoid.Health = health
		return `Set {target.Name}'s Health to {health}`
	end
}
