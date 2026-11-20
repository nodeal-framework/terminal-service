return {
	Name = "strip",
	Permission = "Admin",
	Description = "Removes all equipped tools, accessories, shirts, pants and shirt graphics from a player",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player" }
	},
	Run = function(context, target: Player)
		if not target.Character then
			context:Error(`{target.Name} has no character`)
			return
		end
		local removed = 0
		for _, item in target.Character:GetChildren() do
			if item:IsA("Tool") or item:IsA("Accessory")
				or item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") then
				item:Destroy()
				removed += 1
			end
		end
		if target:FindFirstChild("Backpack") then
			for _, item in target.Backpack:GetChildren() do
				if item:IsA("Tool") then
					item:Destroy()
					removed += 1
				end
			end
		end
		return `Stripped {removed} item(s) from {target.Name}`
	end
}
