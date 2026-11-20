return {
	Name = "unforcefield",
	Aliases = { "unff" },
	Permission = "Admin",
	Description = "Removes the ForceField from a player's character",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" }
	},
	Run = function(context, target: Player)
		if not target.Character then
			context:Error(`{target.Name} has no character`)
			return
		end
		local ff = target.Character:FindFirstChildOfClass("ForceField")
		if not ff then
			return `{target.Name} has no ForceField`
		end
		ff:Destroy()
		return `ForceField removed from {target.Name}`
	end
}
