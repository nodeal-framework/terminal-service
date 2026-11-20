return {
	Name = "unsmoke",
	Description = "Removes smoke from a player",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player" }
	},
	Run = function(context, target: Player)
		if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			local s = target.Character.HumanoidRootPart:FindFirstChild("AdminSmoke")
			if s then
				s:Destroy()
				return `Removed smoke from {target.Name}`
			end
			return `{target.Name} does not have smoke`
		end
		context:Error(`Could not remove smoke from {target.Name}`)
	end
}
