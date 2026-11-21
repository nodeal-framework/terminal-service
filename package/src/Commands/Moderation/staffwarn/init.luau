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
	Implements the `staffwarn` command: Sends a stylized staff warning
	(severity: INFO/WARN/ERROR/CRITICAL/SUCCESS).
]=]

return {
	Name = "staffwarn",
	Aliases = { "swarn" },
	Permission = "Moderator",
	Description = "Sends a stylized staff warning (severity: INFO/WARN/ERROR/CRITICAL/SUCCESS)",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player to warn" },
		{
			Name = "Severity",
			Type = "string",
			Description = "INFO, WARN, ERROR, CRITICAL, or SUCCESS",
			Default = "WARN",
		},
		{ Name = "Message", Type = "string", Description = "Warning message" },
	},
	--[=[
		Sends a stylized staff warning (severity: INFO/WARN/ERROR/CRITICAL/SUCCESS).

		@param context The command context.
		@param target Player to warn
		@param severity INFO, WARN, ERROR, CRITICAL, or SUCCESS
		@param message Warning message
		@return A status message when the command succeeds.
	]=]
	Run = function(context, target: Player, severity: string, message: string)
		local kind = string.upper(severity)
		local kindForColor
		if kind == "INFO" then
			kindForColor = "Info"
		elseif kind == "SUCCESS" then
			kindForColor = "Success"
		else
			kindForColor = "Error"
		end

		local prefix = if kind == "CRITICAL" then "[!!CRITICAL!!]" else `[!{kind}!]`
		context.Terminal:PrintTo(target, `{prefix} {message}`, kindForColor)
		return `StaffWARN {target.Name} ({kind}): {message}`
	end,
}
