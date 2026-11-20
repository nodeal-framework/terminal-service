return {
	Name = "uptime",
	Permission = "Any",
	Description = "Shows how long the server has been running",
	Run = function(context)
		local s = context.Terminal:GetUptime()
		local days = math.floor(s / 86400)
		local hrs = math.floor((s % 86400) / 3600)
		local mins = math.floor((s % 3600) / 60)
		local secs = math.floor(s % 60)
		return string.format("Uptime: %dd %02dh %02dm %02ds", days, hrs, mins, secs)
	end
}
