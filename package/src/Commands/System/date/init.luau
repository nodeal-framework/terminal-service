return {
	Name = "date",
	Description = "Shows the current server time",
	Permission = "Any",
	Args = {},
	Run = function(context)
		local t = os.time()
		local d = os.date("!*t", t)
		return string.format("UTC Time: %04d-%02d-%02d %02d:%02d:%02d", d.year, d.month, d.day, d.hour, d.min, d.sec)
	end
}
