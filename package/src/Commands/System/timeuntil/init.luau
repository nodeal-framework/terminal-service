return {
	Name = "timeuntil",
	Description = "Calculates the time remaining until a specified date",
	Permission = "Any",
	Args = {
		{ Name = "TargetDate", Type = "DateTime", Description = "The date to calculate time until" }
	},
	Run = function(context, targetDate: DateTime)
		local currentTimestamp = os.time()
		local difference = targetDate.UnixTimestamp - currentTimestamp

		if difference < 0 then
			difference = math.abs(difference)
			local days = math.floor(difference / 86400)
			return `That date was {days} days ago!`
		elseif difference == 0 then
			return "That is today!"
		else
			local days = math.floor(difference / 86400)
			return `{days} days remaining until that date.`
		end
	end
}
