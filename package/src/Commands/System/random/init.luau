--[[
    © 2026 Nodeal Package. All rights reserved.

    This source code is open-source and free for modification and use in your projects.
    However, you may not sell, sublicense, or distribute this framework (or 
    any rebranded version of it) as a standalone product.

    Any public use or redistribution of this module requires this header 
    to remain intact in the source code. For the complete license terms, 
    please visit: https://www.nodeal.dev/license
]]

--[=[
	Implements the `random` command: Generates a random number within a range.
	Defaults to integer; pass 'false' as last arg for float.
]=]

return {
	Name = "random",
	Permission = "Any",
	Aliases = { "roll", "rand", "randint" },
	Description = "Generates a random number within a range. Defaults to integer; "
		.. "pass 'false' as last arg for float",
	Args = {
		{
			Name = "Min",
			Type = "number",
			Description = "Minimum value",
			Default = 1,
			Optional = true,
		},
		{ Name = "Max", Type = "number", Description = "Maximum value", Default = 100 },
		{
			Name = "Integer",
			Type = "boolean",
			Description = "True = integer, False = float (decimal)",
			Default = true,
			Optional = true,
		},
	},
	--[=[
		Generates a random number within a range. Defaults to integer; pass 'false'
		as last arg for float.

		@param context The command context.
		@param minimum Minimum value
		@param maximum Maximum value
		@param integer True = integer, False = float (decimal)
		@return A status message when the command succeeds.
	]=]
	Run = function(context, minimum, maximum, integer)
		if maximum < minimum then
			context:Error(`Max ({maximum}) is less than Min ({minimum})`)
			return
		end
		if integer then
			return tostring(math.random(minimum, maximum))
		end
		return string.format("%.4f", minimum + math.random() * (maximum - minimum))
	end,
}
