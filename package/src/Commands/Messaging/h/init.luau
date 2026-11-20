return {
	Name = "h",
	Permission = "Moderator", -- text in every player's terminal
	Aliases = { "hint" },
	Description = "Broadcasts a subtle hint to every online player's terminal",
	Args = {
		{ Name = "Message", Type = "string", Description = "Hint text" }
	},
	Run = function(context, message: string)
		context.Terminal:Broadcast(message, "Hint")
		return `Hint: {message}`
	end
}
