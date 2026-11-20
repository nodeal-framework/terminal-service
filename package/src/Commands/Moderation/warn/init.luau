return {
	Name = "warn",
	Permission = "Moderator",
	Description = "Sends a warning message that appears prominently in the target's terminal",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player to warn" },
		{ Name = "Message", Type = "string", Description = "Warning message" }
	},
	Run = function(context, target: Player, message: string)
		context.Terminal:PrintTo(target, `WARNING: {message}`, "Error")
		return `Warned {target.Name}: {message}`
	end
}
