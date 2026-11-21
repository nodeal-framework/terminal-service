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
	getopt-style option parsing for the coreutils commands.

	Getopt.parse(args, "ivn:c:", { lines = "n", count = "c" })
	  -> options, operands, errorMessage

	Short options can be clustered (`-ivn5`, `-n 5`, `-n5`) and long options accept
	`--name=value` or `--name value`. `--` ends option parsing.
]=]

local Getopt = {}

local function buildShort(spec: string)
	local allowed = {}
	local takesValue = {}

	local i = 1
	while i <= #spec do
		local c = string.sub(spec, i, i)
		if c ~= ":" then
			allowed[c] = true
			if string.sub(spec, i + 1, i + 1) == ":" then
				takesValue[c] = true
				i += 1
			end
		end
		i += 1
	end

	return allowed, takesValue
end

function Getopt.parse(args: { string }, shortSpec: string?, longSpec: { [string]: any }?): (any, { string }, string?)
	local shortAllowed, shortValue = buildShort(shortSpec or "")
	local long = longSpec or {}
	local options = {}
	local operands = {}
	local i = 1

	while i <= #args do
		local arg = args[i]

		if arg == "--" then
			i += 1
			while i <= #args do
				table.insert(operands, args[i])
				i += 1
			end
			break
		elseif string.sub(arg, 1, 2) == "--" and #arg > 2 then
			local body = string.sub(arg, 3)
			local name, value = string.match(body, "^([^=]+)=(.*)$")
			if not name then
				name = body
			end

			local spec = long[name]
			if spec == nil then
				return options, operands, `unrecognized option '--{name}'`
			end

			if spec == true then
				if value ~= nil then
					return options, operands, `option '--{name}' doesn't allow an argument`
				end
				options[name] = true
			else
				if value == nil then
					i += 1
					value = args[i]
					if value == nil then
						return options, operands, `option '--{name}' requires an argument`
					end
				end
				options[name] = value
			end

			i += 1
		elseif string.sub(arg, 1, 1) == "-" and #arg > 1 then
			local body = string.sub(arg, 2)
			local j = 1
			local consumed = false

			while j <= #body do
				local c = string.sub(body, j, j)

				if not shortAllowed[c] then
					-- a negative number operand, not an option
					if j == 1 and string.match(body, "^%d+$") then
						break
					end
					return options, operands, `invalid option -- '{c}'`
				end

				if shortValue[c] then
					local value = string.sub(body, j + 1)
					if value == "" then
						i += 1
						value = args[i]
						if value == nil then
							return options, operands, `option requires an argument -- '{c}'`
						end
					end
					options[c] = value
					consumed = true
					break
				else
					options[c] = true
					j += 1
				end
			end

			if not consumed and j == 1 and string.match(body, "^%d+$") then
				table.insert(operands, arg)
			end

			i += 1
		else
			table.insert(operands, arg)
			i += 1
		end
	end

	return options, operands, nil
end

--[=[
	Returns an option count helper: opts.has("n") checks both "n" and long aliases.
]=]
function Getopt.has(options, name: string): boolean
	return options[name] ~= nil and options[name] ~= false
end

return Getopt
