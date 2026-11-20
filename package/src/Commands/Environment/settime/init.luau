local Lighting = game:GetService("Lighting")

return {
	Name = "settime",
	Aliases = { "timeofday" },
	Description = "Sets the time of day",
	Permission = "Admin",
	Args = {
		{ Name = "Time", Type = "time", Description = "Time of day" }
	},
	Run = function(context, timeString: string)
		Lighting.TimeOfDay = timeString
		return `Set time of day to {timeString}`
	end
}
