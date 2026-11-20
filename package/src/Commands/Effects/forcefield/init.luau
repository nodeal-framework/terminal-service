return {
	Name = "forcefield",
	Aliases = { "ff" },
	Permission = "Admin",
	Description = "Applies a ForceField to a player's character",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" }
	},
	Run = function(context, target: Player)
		if not target.Character then
			context:Error(`{target.Name} has no character`)
			return
		end
		if target.Character:FindFirstChildOfClass("ForceField") then
			return `{target.Name} already has a ForceField`
		end
		local ff = Instance.new("ForceField")
		ff.Parent = target.Character
		return `ForceField applied to {target.Name}`
	end
}
