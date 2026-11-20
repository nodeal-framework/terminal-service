local Players = game:GetService("Players")

return {
	Name = "sm",
	Aliases = { "system", "systemchat" },
	Permission = "Admin",
	Description = "Broadcasts a chat message from 'System' in the standard chat channels for all players",
	Args = {
		{ Name = "Message", Type = "string", Description = "Message text" }
	},
	Run = function(context, message: string)
		for _, p in Players:GetPlayers() do
			context.Terminal:SendSystemChat(p, message)
		end
		return `System: {message}`
	end
}
