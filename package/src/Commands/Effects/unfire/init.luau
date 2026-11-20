return {
	Name = "unfire",
	Description = "Removes fire from a player",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player" }
	},
	Run = function(context, target: Player)
		if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			local s = target.Character.HumanoidRootPart:FindFirstChild("AdminFire")
			if s then
				s:Destroy()
				return `Removed fire from {target.Name}`
			end
			return `{target.Name} does not have fire`
		end
		context:Error(`Could not remove fire from {target.Name}`)
	end
}
