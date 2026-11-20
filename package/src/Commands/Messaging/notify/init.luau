return {
	Name = "notify",
	Aliases = { "toast" },
	Permission = "Admin",
	Description = "Sends a styled notification to one or more players' terminals",
	Args = {
		{ Name = "Target", Type = "Player", Description = "Recipient player(s)" },
		{ Name = "Message", Type = "string", Description = "Notification text" },
		{ Name = "Kind", Type = "string", Description = "Info, Success, or Error (default: Info)", Default = "Info" }
	},
	Run = function(context, target: any, message: string, kind: string)
		context.Terminal:PrintTo(target, message, kind)
		return `Notified {typeof(target) == "Instance" and target.Name or "targets"}: {message}`
	end
}
