return {
	Name = "serverunlock",
	Aliases = { "unslock" },
	Permission = "Admin",
	Description = "Unlocks the server to allow new joiners",
	Run = function(context)
		local TerminalService = context.Terminal
		TerminalService.Locked = false

		if TerminalService.LockConnection then
			TerminalService.LockConnection:Disconnect()
			TerminalService.LockConnection = nil
		end

		return "Server unlocked. New players can join."
	end
}
