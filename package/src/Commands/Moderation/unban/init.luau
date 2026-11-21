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
	Implements the `unban` command: Unbans a user from the game by UserId.
]=]

local Players = game:GetService("Players")

return {
	Name = "unban",
	Permission = "Admin",
	Description = "Unbans a user from the game by UserId",
	Args = {
		{ Name = "UserId", Type = "number", Description = "UserId to unban" },
	},
	--[=[
		Unbans a user from the game by UserId.

		@param context The command context.
		@param userId UserId to unban
		@return A status message when the command succeeds.
	]=]
	Run = function(context, userId: number)
		local success, errorValue = pcall(function()
			Players:UnbanAsync({ UserIds = { userId } })
		end)
		if success then
			return `Unbanned user {userId}`
		end
		context:Error(`Failed to unban: {errorValue}`)
	end,
}
