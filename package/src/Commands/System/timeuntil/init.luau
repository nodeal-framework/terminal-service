--[[
    © 2026 Nodeal Package. All rights reserved.

    This source code is open-source and free for modification and use in your projects.
    However, you may not sell, sublicense, or distribute this framework (or 
    any rebranded version of it) as a standalone product.

    Any public use or redistribution of this module requires this header 
    to remain intact in the source code. For the complete license terms, 
    please visit: https://www.nodeal.dev/license
]]

--[=[
	Implements the `timeuntil` command: Calculates the time remaining until a
	specified date.
]=]

return {
	Name = "timeuntil",
	Description = "Calculates the time remaining until a specified date",
	Permission = "Any",
	Args = {
		{
			Name = "TargetDate",
			Type = "DateTime",
			Description = "The date to calculate time until",
		},
	},
	--[=[
		Calculates the time remaining until a specified date.

		@param context The command context.
		@param targetDate The date to calculate time until
		@return A status message when the command succeeds.
	]=]
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
	end,
}
