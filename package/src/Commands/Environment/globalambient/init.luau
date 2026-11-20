return {
	Name = "globalambient",
	Aliases = { "gambient" },
	Permission = "Admin",
	Description = "Sets the Lighting.OutdoorAmbient color globally",
	Args = {
		{ Name = "Color", Type = "Color3", Description = "Outdoor ambient color" }
	},
	Run = function(context, color: Color3)
		game:GetService("Lighting").OutdoorAmbient = color
		return `Outdoor ambient set to {color:ToHex()}`
	end
}
