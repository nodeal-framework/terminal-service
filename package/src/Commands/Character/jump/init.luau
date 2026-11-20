return {
	Name = "jump",
	Aliases = { "jumppower", "jp" },
	Description = "Sets a player's jump power",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player to set the jump power of" },
		{ Name = "Power", Type = "number", Description = "The jump power" }
	},
	Run = function(context, target: Player, power: number)
		if target.Character and target.Character:FindFirstChild("Humanoid") then
			target.Character.Humanoid.UseJumpPower = true
			target.Character.Humanoid.JumpPower = power
			return `Set {target.Name}'s jump power to {power}`
		end
		context:Error(`Could not set jump power for {target.Name}`)
	end
}
