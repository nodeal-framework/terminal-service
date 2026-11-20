local Players = game:GetService("Players")

return {
	Name = "shutdown",
	Permission = "Admin",
	Description = "Kicks all players and shuts the server down",
	Args = {
		{ Name = "Reason", Type = "string", Description = "Kick reason (also saved)", Default = "Server shutting down" }
	},
	Run = function(context, reason: string)
		for _, p in Players:GetPlayers() do
			p:Kick(reason)
		end
		task.delay(2, function()
			game:Shutdown()
		end)
		return `Shutting down: {reason}`
	end
}
