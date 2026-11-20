return {
	Name = "platformstand",
	Aliases = { "platstand" },
	Permission = "Admin",
	Description = "Toggles PlatformStand (Ragdoll) on a player",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
		{ Name = "State", Type = "boolean", Description = "True = enable, False = disable", Default = true }
	},
	Run = function(context, target: Player, state: boolean)
		if target.Character and target.Character:FindFirstChildOfClass("Humanoid") then
			target.Character.Humanoid.PlatformStand = state
			return `{target.Name}: PlatformStand = {tostring(state)}`
		end
		context:Error(`Could not change PlatformStand for {target.Name}`)
	end
}
