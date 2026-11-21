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
	Implements the `limit` command: Keep at most N lines of stdin (there is no
	filesystem to truncate).
]=]

local Getopt = require(script.Parent.Parent.Parent.Parent.Classes.Getopt)
local Text = require(script.Parent.Parent.Parent.Parent.Classes.Text)

return {
	Name = "limit",
	Permission = "Any",
	Aliases = { "trunc" },
	Description = "Keep at most N lines of stdin (there is no filesystem to truncate)",
	Args = {},
	--[=[
		Keep at most N lines of stdin (there is no filesystem to truncate).

		@param context The command context.
		@return A status message when the command succeeds.
	]=]
	Run = function(context)
		local options, operands, errorValue = Getopt.parse(context.Args, "n:", {
			lines = "n",
		})

		if errorValue then
			context:Error(`limit: {errorValue}`, 2)
			return ""
		end

		local count = Text.number(options.n or (operands[1] or "10"))
		if not count or count < 0 then
			context:Error("limit: invalid line count", 2)
			return ""
		end

		local out = {}
		local index = 0
		for _, line in Text.lines(context:GetInput()) do
			if index >= count then
				break
			end
			table.insert(out, line)
			index += 1
		end
		return table.concat(out, "\n")
	end,
}
