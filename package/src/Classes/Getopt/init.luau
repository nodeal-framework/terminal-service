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

--[=[
	Indexes a short option specification.

	@param spec The specification to parse.
	@return The short option index.
]=]
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

--[=[
	Parses GNU-style short and long options.

	@param arguments The command arguments.
	@param shortSpec The short option specification.
	@param longSpec The long option table.
	@return The exit status, standard output and standard error.
]=]
function Getopt.parse(
	arguments: { string },
	shortSpec: string?,
	longSpec: { [string]: any }?
): (any, { string }, string?)
	local shortAllowed, shortValue = buildShort(shortSpec or "")
	local long = longSpec or {}
	local options = {}
	local operands = {}
	local i = 1

	while i <= #arguments do
		local argument = arguments[i]

		if argument == "--" then
			i += 1
			while i <= #arguments do
				table.insert(operands, arguments[i])
				i += 1
			end
			break
		elseif string.sub(argument, 1, 2) == "--" and #argument > 2 then
			local body = string.sub(argument, 3)
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
					value = arguments[i]
					if value == nil then
						return options, operands, `option '--{name}' requires an argument`
					end
				end
				options[name] = value
			end

			i += 1
		elseif string.sub(argument, 1, 1) == "-" and #argument > 1 then
			local body = string.sub(argument, 2)
			local j = 1
			local consumed = false

			while j <= #body do
				local c = string.sub(body, j, j)

				if not shortAllowed[c] then
					if j == 1 and string.match(body, "^%d+$") then
						break
					end
					return options, operands, `invalid option -- '{c}'`
				end

				if shortValue[c] then
					local value = string.sub(body, j + 1)
					if value == "" then
						i += 1
						value = arguments[i]
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
				table.insert(operands, argument)
			end

			i += 1
		else
			table.insert(operands, argument)
			i += 1
		end
	end

	return options, operands, nil
end

--[=[
	Returns an option count helper: opts.has("n") checks both "n" and long aliases.

	@param options The parsed options.
	@param name The name to look up.
]=]
function Getopt.has(options, name: string): boolean
	return options[name] ~= nil and options[name] ~= false
end

return Getopt
