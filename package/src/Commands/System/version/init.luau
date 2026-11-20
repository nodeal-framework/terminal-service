return {
	Name = "version",
	Permission = "Any",
	Aliases = { "ver" },
	Description = "Shows game and TerminalService version info",
	Run = function(context)
		return string.format("PlaceVersion: %s | PlaceId: %d | TerminalService: 1.0.0",
			tostring(game.PlaceVersion), game.PlaceId)
	end
}
