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
	Implements the `sha256sum` command: Compute the SHA-256 checksum of stdin.
]=]

local Getopt = require(script.Parent.Parent.Parent.Parent.Classes.Getopt)
local Hash = require(script.Parent.Parent.Parent.Parent.Classes.Hash)

return {
	Name = "sha256sum",
	Permission = "Any",
	Description = "Compute the SHA-256 checksum of stdin",
	Args = {},
	--[=[
		Compute the SHA-256 checksum of stdin.

		@param context The command context.
		@return A status message when the command succeeds.
	]=]
	Run = function(context)
		local options, operands, errorValue = Getopt.parse(context.Args, "bct", {
			binary = "b",
			text = "t",
			check = "c",
		})

		if errorValue then
			context:Error(`sha256sum: {errorValue}`, 2)
			return ""
		end

		if options.c then
			context:Error("sha256sum: -c: there is no filesystem", 2)
			return ""
		end

		if #operands > 0 then
			context:Error(`sha256sum: {operands[1]}: No such file or directory`, 1)
			return ""
		end

		return Hash.sha256(context:GetInput()) .. "  -"
	end,
}
