local Players = game:GetService("Players")

return {
	Name = "ban",
	Aliases = { "tempban" },
	Description = "Bans a player from the game",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player to ban" },
		{ Name = "Duration", Type = "date | duration", Description = "Date or duration (e.g. 1d, 2h) or -1", Default = -1 },
		{ Name = "Reason", Type = "string", Description = "Reason for the ban", Default = "No reason" }
	},
	Run = function(context, target: Player, duration: number, reason: string)
		local config = {
			UserIds = { target.UserId },
			DisplayReason = reason,
			PrivateReason = reason,
			ExcludeAltAccounts = false,
			ApplyToUniverse = true
		}

		-- If it's a date timestamp, subtract current time to get duration
		if duration > 1000000000 then -- Simple heuristic to detect unix timestamps vs seconds
			duration = math.floor(duration - os.time())
		end

		if duration > 0 then
			config.Duration = duration
		end

		local success, err = pcall(function()
			Players:BanAsync(config)
		end)

		if success then
			if duration > 0 then
				return `Successfully banned {target.Name} for {duration} seconds. Reason: {reason}`
			else
				return `Successfully permanently banned {target.Name}. Reason: {reason}`
			end
		else
			context:Error(`Failed to ban {target.Name}: {err}`)
		end
	end
}
