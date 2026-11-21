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
	Implements the `fmt` command: Reflow text to a given width.
]=]

local Getopt = require(script.Parent.Parent.Parent.Parent.Classes.Getopt)
local Text = require(script.Parent.Parent.Parent.Parent.Classes.Text)

return {
	Name = "fmt",
	Permission = "Any",
	Description = "Reflow text to a given width",
	Args = {},
	--[=[
		Reflow text to a given width.

		@param context The command context.
		@return A status message when the command succeeds.
	]=]
	Run = function(context)
		local options, operands, errorValue = Getopt.parse(context.Args, "w:sup:", {
			width = "w",
			split_only = "s",
			uniform = "u",
			prefix = "p",
		})

		if errorValue then
			context:Error(`fmt: {errorValue}`, 2)
			return ""
		end

		if #operands > 0 then
			context:Error(`fmt: {operands[1]}: No such file or directory`, 2)
			return ""
		end

		local width = tonumber(options.w) or 75
		if width < 1 then
			context:Error("fmt: invalid width", 2)
			return ""
		end

		local prefix = options.p or ""
		local lines = Text.lines(context:GetInput())
		local out = {}
		local paragraph = {}

		--[=[
			Flushes the current paragraph.
		]=]
		local function flush()
			if #paragraph == 0 then
				return
			end

			if options.s then
				for _, line in paragraph do
					table.insert(out, prefix .. line)
				end
				paragraph = {}
				return
			end

			local words = {}
			for _, line in paragraph do
				for word in string.gmatch(line, "%S+") do
					table.insert(words, word)
				end
			end
			paragraph = {}

			local current = prefix
			for _, word in words do
				if current == prefix then
					current = prefix .. word
				elseif #current + 1 + #word <= width then
					current ..= " " .. word
				else
					table.insert(out, current)
					current = prefix .. word
				end
			end
			if current ~= prefix then
				table.insert(out, current)
			end
		end

		for _, line in lines do
			if line == "" then
				flush()
				table.insert(out, "")
			else
				table.insert(paragraph, line)
			end
		end
		flush()

		return table.concat(out, "\n")
	end,
}
