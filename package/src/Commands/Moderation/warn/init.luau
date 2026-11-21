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
	Implements the `warn` command: Sends a warning message that appears
	prominently in the target's terminal.
]=]

return {
	Name = "warn",
	Permission = "Moderator",
	Description = "Sends a warning message that appears prominently in the target's terminal",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player to warn" },
		{ Name = "Message", Type = "string", Description = "Warning message" },
	},
	--[=[
		Sends a warning message that appears prominently in the target's terminal.

		@param context The command context.
		@param target Player to warn
		@param message Warning message
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player, message: string)
		context.Terminal:PrintTo(target, `WARNING: {message}`, "Error")
		return `Warned {target.Name}: {message}`
	end,
}
