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
	Implements the `h` command: Broadcasts a subtle hint to every online
	player's terminal.
]=]

return {
	Name = "h",
	Permission = "Moderator", -- text in every player's terminal
	Aliases = { "hint" },
	Description = "Broadcasts a subtle hint to every online player's terminal",
	Args = {
		{ Name = "Message", Type = "string", Description = "Hint text" },
	},
	--[=[
		Broadcasts a subtle hint to every online player's terminal.

		@param context The command context.
		@param message Hint text
		@return A status message when the command succeeds.
	]=]
	Run = function(context, message: string)
		context.Terminal:Broadcast(message, "Hint")
		return `Hint: {message}`
	end,
}
