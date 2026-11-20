return {
	Name = "pm",
	Aliases = { "whisper", "w" },
	Description = "Sends a private message to one player's terminal",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Recipient player" },
		{ Name = "Message", Type = "string", Description = "Message text" }
	},
	Run = function(context, target: Player, message: string)
		context.Terminal:PrintTo(target, message, "PM")
		return `PM to {target.Name}: {message}`
	end
}
