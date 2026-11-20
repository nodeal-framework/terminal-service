return {
	Name = "paint",
	Permission = "Admin",
	Description = "Paints a player's character BodyColors to the given BrickColor (R6 avatars only)",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" },
		{ Name = "Color", Type = "BrickColor", Description = "Body color" }
	},
	Run = function(context, target: Player, color: BrickColor)
		local char = target.Character
		if not char then
			context:Error(`{target.Name} has no character`)
			return
		end
		local bodyColors = char:FindFirstChild("Body Colors")
		if not bodyColors then
			context:Error(`{target.Name} has no Body Colors (R15 avatars not supported by paint)`)
			return
		end
		for _, sub in bodyColors:GetChildren() do
			if sub:IsA("Color3Value") then
				sub.Value = color.Color
			end
		end
		return `{target.Name}'s body painted to {color.Name}`
	end
}
