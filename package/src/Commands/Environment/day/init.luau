return {
	Name = "day",
	Permission = "Admin",
	Description = "Sets the time of day to noon (12:00:00)",
	Run = function(context)
		game:GetService("Lighting").TimeOfDay = "12:00:00"
		return "Time of day set to noon (12:00)"
	end
}
