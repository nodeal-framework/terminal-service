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
	Implements the `ban` command: Bans a player from the game.
]=]

local Players = game:GetService("Players")

return {
	Name = "ban",
	Aliases = { "tempban" },
	Description = "Bans a player from the game",
	Permission = "Admin",
	Args = {
		{ Name = "Target", Type = "Player", Description = "The player to ban" },
		{
			Name = "Duration",
			Type = "date | duration",
			Description = "Date or duration (e.g. 1d, 2h) or -1",
			Default = -1,
		},
		{
			Name = "Reason",
			Type = "string",
			Description = "Reason for the ban",
			Default = "No reason",
		},
	},
	--[=[
		Bans a player from the game.

		@param context The command context.
		@param target The player to ban
		@param duration Date or duration (e.g. 1d, 2h) or -1
		@param reason Reason for the ban
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player, duration: number, reason: string)
		local config = {
			UserIds = { target.UserId },
			DisplayReason = reason,
			PrivateReason = reason,
			ExcludeAltAccounts = false,
			ApplyToUniverse = true,
		}

		if duration > 1000000000 then
			duration = math.floor(duration - os.time())
		end

		if duration > 0 then
			config.Duration = duration
		end

		local success, errorValue = pcall(function()
			Players:BanAsync(config)
		end)

		if success then
			if duration > 0 then
				return `Successfully banned {target.Name} for {duration} seconds. Reason: {reason}`
			else
				return `Successfully permanently banned {target.Name}. Reason: {reason}`
			end
		else
			context:Error(`Failed to ban {target.Name}: {errorValue}`)
		end
	end,
}
