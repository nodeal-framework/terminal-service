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
	Implements the `notify` command: Sends a styled notification to one or more
	players' terminals.
]=]

return {
	Name = "notify",
	Aliases = { "toast" },
	Permission = "Admin",
	Description = "Sends a styled notification to one or more players' terminals",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Recipient player(s)" },
		{ Name = "Message", Type = "string", Description = "Notification text" },
		{
			Name = "Kind",
			Type = "string",
			Description = "Info, Success, or Error (default: Info)",
			Default = "Info",
		},
	},
	--[=[
		Sends a styled notification to one or more players' terminals.

		@param context The command context.
		@param target Recipient player(s)
		@param message Notification text
		@param kind Info, Success, or Error (default: Info)
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: any, message: string, kind: string)
		context.Terminal:PrintTo(target, message, kind)
		return `Notified {typeof(target) == "Instance" and target.Name or "targets"}: {message}`
	end,
}
