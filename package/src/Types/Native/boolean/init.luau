local truthy = { ["true"] = true, ["yes"] = true, ["1"] = true, ["y"] = true }
local falsy  = { ["false"] = true, ["no"] = true, ["0"] = true, ["n"] = true }

return {
	Validate = function(text: string, executor: Player)
		local lower = string.lower(text)
		if truthy[lower] or falsy[lower] then
			return true
		end
		return false, `'{text}' is not a valid boolean (expected true/false, yes/no, 1/0)`
	end,

	Transform = function(text: string, executor: Player)
		local lower = string.lower(text)
		return truthy[lower] == true
	end,

	Autocomplete = function(text: string, executor: Player, terminalService: any)
		local results = {}
		for _, opt in {"yes", "no"} do
			local score = terminalService.FuzzyMatch(text, opt)
			if score > 0 then
				table.insert(results, { Text = opt, Score = score })
			end
		end
		return results
	end
}
