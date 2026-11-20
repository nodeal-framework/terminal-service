return {
	Name = "clear",
	Aliases = { "cls" },
	Description = "Clears the terminal output",
	Permission = "Any",
	Args = {},
	Run = function(context)
		return "\27[2J"
	end
}
