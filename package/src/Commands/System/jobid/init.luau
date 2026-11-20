return {
	Name = "jobid",
	Permission = "Any",
	Description = "Prints the current server's JobId",
	Run = function(context)
		return `JobId: {game.JobId}`
	end
}
