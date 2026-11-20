return {
	Name = "cleardebris",
	Aliases = { "clean" },
	Permission = "Admin",
	Description = "Removes loose non-anchored Parts from the workspace root (debris cleanup)",
	Run = function(context)
		local removed = 0
		for _, child in workspace:GetChildren() do
			if child:IsA("BasePart") and not child.Anchored then
				child:Destroy()
				removed += 1
			end
		end
		if removed == 0 then return "No debris found in workspace root" end
		return `Cleared {removed} debris`
	end
}
