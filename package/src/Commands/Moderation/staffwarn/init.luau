return {
	Name = "staffwarn",
	Aliases = { "swarn" },
	Permission = "Moderator",
	Description = "Sends a stylized staff warning (severity: INFO/WARN/ERROR/CRITICAL/SUCCESS)",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Player to warn" },
		{ Name = "Severity", Type = "string", Description = "INFO, WARN, ERROR, CRITICAL, or SUCCESS", Default = "WARN" },
		{ Name = "Message", Type = "string", Description = "Warning message" }
	},
	Run = function(context, target: Player, severity: string, message: string)
		local kind = string.upper(severity)
		local kindForColor
		if kind == "INFO" then kindForColor = "Info"
		elseif kind == "SUCCESS" then kindForColor = "Success"
		else kindForColor = "Error" end

		local prefix = if kind == "CRITICAL" then "[!!CRITICAL!!]" else `[!{kind}!]`
		context.Terminal:PrintTo(target, `{prefix} {message}`, kindForColor)
		return `StaffWARN {target.Name} ({kind}): {message}`
	end
}
