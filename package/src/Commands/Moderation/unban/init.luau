local Players = game:GetService("Players")

return {
	Name = "unban",
	Permission = "Admin",
	Description = "Unbans a user from the game by UserId",
	Args = {
		{ Name = "UserId", Type = "number", Description = "UserId to unban" }
	},
	Run = function(context, userId: number)
		local success, err = pcall(function()
			Players:UnbanAsync({ UserIds = { userId } })
		end)
		if success then
			return `Unbanned user {userId}`
		end
		context:Error(`Failed to unban: {err}`)
	end
}
