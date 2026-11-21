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
	Name = "paste",
	Permission = "Any",
	Description = "Merge lines of stdin",
	Args = {},
	Run = function(context)
		local options, operands, err = Getopt.parse(context.Args, "d:sz", {
			delimiters = "d",
			serial = "s",
			zero_terminated = "z",
		})

		if err then
			context:Error(`paste: {err}`, 2)
			return ""
		end

		if #operands > 0 then
			context:Error(`paste: {operands[1]}: No such file or directory`, 2)
			return ""
		end

		local delimiters = options.d or "\t"
		local lines = Text.lines(context:GetInput())

		if options.s then
			local out = {}
			for index, line in lines do
				local delimiter = string.sub(delimiters, ((index - 1) % #delimiters) + 1, ((index - 1) % #delimiters) + 1)
				table.insert(out, line .. (if index < #lines then delimiter else ""))
			end
			return table.concat(out)
		end

		return table.concat(lines, "\n")
	end,
}
