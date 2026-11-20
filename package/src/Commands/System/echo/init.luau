return {
	Name = "echo",
	Permission = "Any",
	Aliases = {},
	Description = "Prints the input message to the terminal output",
	Args = {
		{ Name = "Message", Type = "string", Description = "The message to display", Default = "" }
	},
	Run = function(context, message: string)
		return message
	end
}
