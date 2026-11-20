return {
	Name = "fog",
	Permission = "Admin",
	Description = "Sets fog color, start, and end distances at once",
	Args = {
		{ Name = "Color", Type = "Color3", Description = "Fog color" },
		{ Name = "Start", Type = "number", Description = "Fog start distance" },
		{ Name = "Finish", Type = "number", Description = "Fog end distance" }
	},
	Run = function(context, color: Color3, start: number, finish: number)
		local Lighting = game:GetService("Lighting")
		Lighting.FogColor = color
		Lighting.FogStart = start
		Lighting.FogEnd = finish
		return `Fog set: color {color:ToHex()}, start {start}, end {finish}`
	end
}
