local Lighting = game:GetService("Lighting")

return {
	Name = "setcolor",
	Permission = "Admin",
	Description = "Sets the global ambient lighting color",
	Args = {
		{ Name = "Color", Type = "Color3", Description = "The ambient color to set" }
	},
	Run = function(context, color: Color3)
		Lighting.Ambient = color
		Lighting.OutdoorAmbient = color
		local hex = "#" .. color:ToHex()
		return `Set the ambient color to {hex}`
	end
}
