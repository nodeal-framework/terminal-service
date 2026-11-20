return {
	Name = "wc",
	Permission = "Any",
	Aliases = { "count" },
	Description = "Count lines (l), words (w), or characters (c) of stdin",
	Args = {
		{ Name = "Mode", Type = "string", Description = "l=lines, w=words, c=characters", Default = "l", Optional = true }
	},
	Run = function(context, mode: string)
		local input = context:GetInput()
		if input == "" then return "0" end

		local lower = string.lower(mode)
		if lower == "w" then
			local n = 0
			for _ in string.gmatch(input, "%S+") do n += 1 end
			return tostring(n)
		elseif lower == "c" then
			return tostring(#input)
		else
			local n = 0
			for _ in string.gmatch(input, "[^\n]+") do n += 1 end
			return tostring(n)
		end
	end
}
