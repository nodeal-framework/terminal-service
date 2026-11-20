return {
	Validate = function(text: string, executor: Player)
		local val = tonumber(text)
		if not val then
			return false, `'{text}' is not a valid number`
		end
		return true
	end,

	Transform = function(text: string, executor: Player)
		return tonumber(text)
	end,

	Autocomplete = function(text: string, executor: Player)
		return {}
	end
}
