local Players = game:GetService("Players")

return {
	Name = "serverlock",
	Aliases = { "slock" },
	Permission = "Admin",
	Description = "Locks the server so new players cannot join",
	Run = function(context)
		local TerminalService = context.Terminal
		if TerminalService.Locked then return "Server is already locked" end

		TerminalService.Locked = true
		TerminalService.LockConnection = Players.PlayerAdded:Connect(function(p)
			if TerminalService.Locked then
				p:Kick("Server is currently locked. Try again later.")
			end
		end)

		return "Server locked. New joiners will be rejected."
	end
}
