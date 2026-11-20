return {
	Name = "unblur",
	Permission = "Admin",
	Description = "Removes any active admin blur effect from Lighting",
	Run = function(context)
		local blur = game:GetService("Lighting"):FindFirstChild("AdminBlur")
		if not blur then return "No active blur" end
		blur:Destroy()
		return "Blur removed"
	end
}
