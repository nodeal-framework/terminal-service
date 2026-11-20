return {
	Name = "speed",
	Aliases = { "walkspeed", "ws" },
	Description = "Sets a player's walkspeed",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player to set the speed of" },
		{ Name = "Speed", Type = "number", Description = "The walkspeed" }
	},
	Run = function(context, target: Player, speed: number)
		if target.Character and target.Character:FindFirstChild("Humanoid") then
			target.Character.Humanoid.WalkSpeed = speed
			return `Set {target.Name}'s walkspeed to {speed}`
		end
		context:Error(`Could not set speed for {target.Name}`)
	end
}
