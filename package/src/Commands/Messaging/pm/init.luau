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
	Implements the `pm` command: Sends a private message to one player's
	terminal.
]=]

return {
	Name = "pm",
	Permission = "Moderator",
	Aliases = { "whisper", "w" },
	Description = "Sends a private message to one player's terminal",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Recipient player" },
		{ Name = "Message", Type = "string", Description = "Message text" },
	},
	--[=[
		Sends a private message to one player's terminal.

		@param context The command context.
		@param target Recipient player
		@param message Message text
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player, message: string)
		context.Terminal:PrintTo(target, message, "PM")
		return `PM to {target.Name}: {message}`
	end,
}
