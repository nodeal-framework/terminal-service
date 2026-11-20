return {
	Name = "lower",
	Description = "Convert stdin to lowercase",
	Run = function(context)
		return string.lower(context:GetInput())
	end
}
