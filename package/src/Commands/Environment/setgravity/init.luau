return {
	Name = "setgravity",
	Aliases = { "grav" },
	Permission = "Admin",
	Description = "Adjusts Workspace.Gravity",
	Args = {
		{ Name = "Value", Type = "number", Description = "Gravity (Roblox default: 196.2)", Default = 196.2 }
	},
	Run = function(context, value: number)
		workspace.Gravity = value
		return `Workspace gravity set to {value}`
	end
}
