return {
	Name = "unsparkles",
	Description = "Removes sparkles from a player",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player" }
	},
	Run = function(context, target: Player)
		if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			local s = target.Character.HumanoidRootPart:FindFirstChild("AdminSparkles")
			if s then
				s:Destroy()
				return `Removed sparkles from {target.Name}`
			end
			return `{target.Name} does not have sparkles`
		end
		context:Error(`Could not remove sparkles from {target.Name}`)
	end
}
