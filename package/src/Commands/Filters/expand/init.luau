--[[
    © 2026 Nodeal Package. All rights reserved.

    This source code is open-source and free for modification and use in your projects.
    However, you may not sell, sublicense, or distribute this framework (or 
    any rebranded version of it) as a standalone product.

    Any public use or redistribution of this module requires this header 
    to remain intact in the source code. For the complete license terms, 
    please visit: https://www.nodeal.dev/license
]]

local Getopt = require(script.Parent.Parent.Parent.Parent.Classes.Getopt)
local Text = require(script.Parent.Parent.Parent.Parent.Classes.Text)

local function tabStops(spec: string?): { number }
	local stops = {}
	for value in string.gmatch(spec or "8", "[^,]+") do
		local number = tonumber(value)
		if number and number > 0 then
			table.insert(stops, number)
		end
	end
	if #stops == 0 then stops = { 8 } end
	return stops
end

return {
	Name = "expand",
	Permission = "Any",
	Description = "Convert tabs to spaces",
	Args = {},
	Run = function(context)
		local options, operands, err = Getopt.parse(context.Args, "t:i", {
			tabs = "t",
			initial = "i",
		})

		if err then
			context:Error(`expand: {err}`, 2)
			return ""
		end

		if #operands > 0 then
			context:Error(`expand: {operands[1]}: No such file or directory`, 2)
			return ""
		end

		local stops = tabStops(options.t)
		local out = {}

		for _, line in Text.lines(context:GetInput()) do
			local result = {}
			local column = 0
			for i = 1, #line do
				local c = string.sub(line, i, i)
				if c == "\t" then
					local target = stops[#stops]
					for _, stop in stops do
						if column < stop then
							target = stop
							break
						end
					end
					if target <= column then
						target = column + stops[#stops]
					end
					table.insert(result, string.rep(" ", target - column))
					column = target
				else
					table.insert(result, c)
					column += 1
				end
			end
			table.insert(out, table.concat(result))
		end

		return table.concat(out, "\n")
	end,
}
