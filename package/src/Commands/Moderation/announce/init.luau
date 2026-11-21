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
	Implements the `announce` command: Broadcasts an announcement to every
	online player's terminal.
]=]

return {
	Name = "announce",
	Permission = "Admin",
	Description = "Broadcasts an announcement to every online player's terminal",
	Args = {
		{ Name = "Title", Type = "string", Description = "Title of the announcement" },
		{ Name = "Body", Type = "string", Description = "Body text" },
	},
	--[=[
		Broadcasts an announcement to every online player's terminal.

		@param context The command context.
		@param title Title of the announcement
		@param body Body text
		@return A status message when the command succeeds.
	]=]
	Run = function(context, title: string, body: string)
		context.Terminal:Broadcast(`[ANNOUNCEMENT] {title}: {body}`, "Info")
		return `Announced: {title}`
	end,
}
