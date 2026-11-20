return {
	Name = "upper",
	Description = "Convert stdin to UPPERCASE",
	Run = function(context)
		return string.upper(context:GetInput())
	end
}
