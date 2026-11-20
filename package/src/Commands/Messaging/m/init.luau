return {
	Name = "m",
	Aliases = { "message", "msg" },
	Permission = "Admin",
	Description = "Broadcasts a styled message to every online player's terminal",
	Args = {
		{ Name = "Message", Type = "string", Description = "Message text" }
	},
	Run = function(context, message: string)
		context.Terminal:Broadcast(message, "Message")
		return `Broadcast: {message}`
	end
}
