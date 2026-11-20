return {
	Name = "brightness",
	Permission = "Admin",
	Description = "Adjusts the global Lighting Brightness",
	Args = {
		{ Name = "Value", Type = "number", Description = "Brightness value (default 2)" }
	},
	Run = function(context, value: number)
		game:GetService("Lighting").Brightness = value
		return `Brightness set to {value}`
	end
}
