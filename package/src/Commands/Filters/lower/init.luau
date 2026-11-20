return {
	Name = "lower",
	Permission = "Any",
	Description = "Convert stdin to lowercase",
	Run = function(context)
		return string.lower(context:GetInput())
	end
}
