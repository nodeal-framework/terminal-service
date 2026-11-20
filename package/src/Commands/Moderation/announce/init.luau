return {
	Name = "announce",
	Permission = "Admin",
	Description = "Broadcasts an announcement to every online player's terminal",
	Args = {
		{ Name = "Title", Type = "string", Description = "Title of the announcement" },
		{ Name = "Body", Type = "string", Description = "Body text" }
	},
	Run = function(context, title: string, body: string)
		context.Terminal:Broadcast(`[ANNOUNCEMENT] {title}: {body}`, "Info")
		return `Announced: {title}`
	end
}
