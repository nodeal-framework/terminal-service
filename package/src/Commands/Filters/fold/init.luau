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

return {
	Name = "fold",
	Permission = "Any",
	Description = "Wrap each line of stdin to a fixed width",
	Args = {},
	Run = function(context)
		local options, operands, err = Getopt.parse(context.Args, "w:sb", {
			width = "w",
			spaces = "s",
			bytes = "b",
		})

		if err then
			context:Error(`fold: {err}`, 2)
			return ""
		end

		if #operands > 0 then
			context:Error(`fold: {operands[1]}: No such file or directory`, 2)
			return ""
		end

		local width = tonumber(options.w) or 80
		if width < 1 then
			context:Error("fold: invalid width", 2)
			return ""
		end

		local out = {}
		for _, line in Text.lines(context:GetInput()) do
			if #line <= width then
				table.insert(out, line)
				continue
			end

			local rest = line
			while #rest > width do
				local cut = width
				if options.s then
					local space = string.find(string.sub(rest, 1, width + 1), "%s+$")
					if space then cut = space - 1 end
				end
				if cut < 1 then cut = width end
				table.insert(out, string.sub(rest, 1, cut))
				rest = string.gsub(string.sub(rest, cut + 1), "^%s+", "")
			end
			if rest ~= "" then table.insert(out, rest) end
		end

		return table.concat(out, "\n")
	end,
}
