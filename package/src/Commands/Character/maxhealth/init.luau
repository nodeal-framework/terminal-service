return {
	Name = "maxhealth",
	Aliases = { "maxhp" },
	Permission = "Admin",
	Description = "Sets a player's MaxHealth",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
		{ Name = "MaxHealth", Type = "number", Description = "Maximum health value" }
	},
	Run = function(context, target, maxHp)
		if not target.Character or not target.Character:FindFirstChildOfClass("Humanoid") then
			context:Error(`{target.Name} has no Humanoid`)
			return
		end
		local hum = target.Character.Humanoid
		hum.MaxHealth = maxHp
		if hum.Health > maxHp then hum.Health = maxHp end
		return `Set {target.Name}'s MaxHealth to {maxHp}`
	end
}
