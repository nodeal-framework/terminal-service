return {
	Name = "night",
	Permission = "Admin",
	Description = "Sets the time of day to midnight (00:00:00)",
	Run = function(context)
		game:GetService("Lighting").TimeOfDay = "00:00:00"
		return "Time of day set to midnight (00:00)"
	end
}
