return {
	Validate = function(text: string, executor: Player)
		return true
	end,

	Transform = function(text: string, executor: Player)
		return text
	end,

	Autocomplete = function(text: string, executor: Player)
		return {}
	end
}
