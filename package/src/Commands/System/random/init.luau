return {
	Name = "random",
	Aliases = { "roll", "rand", "randint" },
	Description = "Generates a random number within a range. Defaults to integer; pass 'false' as last arg for float",
	Args = {
		{ Name = "Min", Type = "number", Description = "Minimum value", Default = 1, Optional = true },
		{ Name = "Max", Type = "number", Description = "Maximum value", Default = 100 },
		{ Name = "Integer", Type = "boolean", Description = "True = integer, False = float (decimal)", Default = true, Optional = true }
	},
	Run = function(context, min, max, integer)
		if max < min then
			context:Error(`Max ({max}) is less than Min ({min})`)
			return
		end
		if integer then
			return tostring(math.random(min, max))
		end
		return string.format("%.4f", min + math.random() * (max - min))
	end
}
