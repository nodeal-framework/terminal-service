return {
	Name = "highlight",
	Permission = "Admin",
	Description = "Applies a Highlight instance to a player's character",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
		{ Name = "Color", Type = "Color3", Description = "Highlight color", Default = Color3.fromRGB(255, 255, 0), Optional = true }
	},
	Run = function(context, target: Player, color: Color3)
		local char = target.Character
		if not char then
			context:Error(`{target.Name} has no character`)
			return
		end
		local existing = char:FindFirstChild("AdminHighlight")
		if existing then existing:Destroy() end

		local hl = Instance.new("Highlight")
		hl.Name = "AdminHighlight"
		hl.FillColor = color
		hl.OutlineColor = color
		hl.Parent = char
		return `Highlight applied to {target.Name}`
	end
}
