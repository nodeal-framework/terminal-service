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
	Implements the `uniq` command: Filter adjacent matching lines from stdin.
]=]

local Getopt = require(script.Parent.Parent.Parent.Parent.Classes.Getopt)
local Text = require(script.Parent.Parent.Parent.Parent.Classes.Text)

return {
	Name = "uniq",
	Permission = "Any",
	Description = "Filter adjacent matching lines from stdin",
	Args = {},
	--[=[
		Filter adjacent matching lines from stdin.

		@param context The command context.
		@return A status message when the command succeeds.
	]=]
	Run = function(context)
		local options, operands, errorValue = Getopt.parse(context.Args, "cduif:s:w:z", {
			count = "c",
			repeated = "d",
			unique = "u",
			ignore_case = "i",
			skip_fields = "f",
			skip_chars = "s",
			check_chars = "w",
			zero_terminated = "z",
		})

		if errorValue then
			context:Error(`uniq: {errorValue}`, 2)
			return ""
		end

		if #operands > 0 then
			context:Error(`uniq: {operands[1]}: No such file or directory`, 2)
			return ""
		end

		local skipFields = tonumber(options.f) or 0
		local skipChars = tonumber(options.s) or 0
		local checkChars = tonumber(options.w)
		local ignoreCase = options.i == true

		--[=[
			Returns the comparison key for a line.

			@param line The line to process.

			@return The resulting text.
		]=]
		local function keyOf(line: string): string
			local value = line
			if skipFields > 0 then
				local index = 1
				for _ = 1, skipFields do
					local _, nextIndex = string.find(value, "%s*%S+", index)
					if not nextIndex then
						value = ""
						break
					end
					index = nextIndex + 1
				end
				value = string.sub(value, index)
			end
			if skipChars > 0 then
				value = string.sub(value, skipChars + 1)
			end
			if checkChars then
				value = string.sub(value, 1, checkChars)
			end
			if ignoreCase then
				value = string.lower(value)
			end
			return value
		end

		local lines = Text.lines(context:GetInput())
		local out = {}
		local index = 1

		while index <= #lines do
			local key = keyOf(lines[index])
			local count = 1
			local j = index + 1
			while j <= #lines and keyOf(lines[j]) == key do
				count += 1
				j += 1
			end

			local include = true
			if options.d then
				include = count > 1
			end
			if options.u then
				include = count == 1
			end

			if include then
				if options.c then
					table.insert(
						out,
						string.rep(" ", math.max(0, 7 - #tostring(count)))
							.. tostring(count)
							.. " "
							.. lines[index]
					)
				else
					table.insert(out, lines[index])
				end
			end

			index = j
		end

		return table.concat(out, if options.z then "\0" else "\n")
	end,
}
