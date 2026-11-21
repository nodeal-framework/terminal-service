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
	grep implementation shared by `grep` and `grepv`.

	With no filesystem, input always comes from stdin. The pattern is an ERE by
	default; `-F` switches to literal matching. The exit status follows GNU grep:
	0 when a line matched, 1 when none did, 2 on usage errors.
]=]

local Getopt = require(script.Parent.Parent.Getopt)
local Regex = require(script.Parent.Parent.Regex)
local Text = require(script.Parent.Parent.Text)

local Grep = {}

local function literalPattern(text: string): string
	return (string.gsub(text, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

local function wordMatch(text: string, s: number, e: number): boolean
	local before = if s > 1 then string.sub(text, s - 1, s - 1) else ""
	local after = if e < #text then string.sub(text, e + 1, e + 1) else ""
	return not string.match(before, "[%w_]") and not string.match(after, "[%w_]")
end

function Grep.run(context, args: { string }, defaultInvert: boolean?): (number, string, string)
	local options, operands, err = Getopt.parse(args, "ivncoqwxEFe:A:B:C:m:slLhHrf", {
		ignore_case = "i",
		invert_match = "v",
		line_number = "n",
		count = "c",
		only_matching = "o",
		quiet = "q",
		word_regexp = "w",
		line_regexp = "x",
		fixed_strings = "F",
		extended_regexp = "E",
		basic_regexp = "G",
		regexp = "e",
		after_context = "A",
		before_context = "B",
		context = "C",
		max_count = "m",
		no_messages = "s",
		files_with_matches = "l",
		files_without_match = "L",
		no_filename = "h",
		with_filename = "H",
	})

	if err then
		return 2, "", `grep: {err}`
	end

	local patterns = {}
	if options.e then
		table.insert(patterns, options.e)
	end

	if #operands > 0 then
		if #patterns == 0 then
			table.insert(patterns, table.remove(operands, 1))
		end
	end

	if #patterns == 0 then
		return 2, "", "grep: no pattern given"
	end

	if #operands > 0 then
		return 2, "", `grep: {operands[1]}: No such file or directory`
	end

	if options.f then
		return 2, "", "grep: -f: there is no filesystem"
	end

	if options.r then
		return 2, "", "grep: -r: there is no filesystem"
	end

	local ignoreCase = options.i == true
	local literal = options.F == true
	local invert = if defaultInvert then not (options.v == true) else options.v == true
	local lineNumber = options.n == true
	local countOnly = options.c == true
	local onlyMatching = options.o == true
	local quiet = options.q == true
	local word = options.w == true
	local wholeLine = options.x == true
	local maxCount = tonumber(options.m)

	local after = tonumber(options.A) or tonumber(options.C) or 0
	local before = tonumber(options.B) or tonumber(options.C) or 0

	-- context above a match: keep a sliding window
	local lines = Text.lines(context:GetInput())
	local basic = options.E ~= true
	local matchers = {}

	for _, pattern in patterns do
		if literal then
			table.insert(matchers, { Literal = if ignoreCase then string.lower(pattern) else pattern })
		else
			local translated = if basic then Regex.breToEre(pattern) else pattern
			local compiled = Regex.compile(translated, ignoreCase)
			table.insert(matchers, { Regex = compiled })
		end
	end

	local function matches(line: string): boolean
		for _, matcher in matchers do
			if matcher.Literal then
				local haystack = if ignoreCase then string.lower(line) else line
				local found = string.find(haystack, matcher.Literal, 1, true)
				if found and (not word or wordMatch(haystack, found, found + #matcher.Literal - 1)) then
					return true
				end
			else
				local s, e = matcher.Regex:Find(line)
				if s and (not word or wordMatch(line, s, e)) and (not wholeLine or (s == 1 and e == #line)) then
					return true
				end
			end
		end
		return false
	end

	local function matchedSegments(line: string): { string }
		local segments = {}
		for _, matcher in matchers do
			if matcher.Regex then
				for _, range in matcher.Regex:FindAll(line) do
					table.insert(segments, string.sub(line, range[1], range[2]))
				end
			else
				local haystack = if ignoreCase then string.lower(line) else line
				local init = 1
				while init <= #haystack do
					local s, e = string.find(haystack, matcher.Literal, init, true)
					if not s then break end
					table.insert(segments, string.sub(line, s, e))
					init = e + 1
				end
			end
		end
		return segments
	end

	if quiet then
		for _, line in lines do
			if matches(line) ~= invert then
				return 0, "", ""
			end
		end
		return 1, "", ""
	end

	local out = {}
	local selected = {}
	local count = 0

	for index, line in lines do
		local isMatch = matches(line)
		local include = if invert then not isMatch else isMatch

		if include then
			count += 1
			selected[index] = true

			if onlyMatching and not invert then
				for _, segment in matchedSegments(line) do
					table.insert(out, if lineNumber then `{index}:{segment}` else segment)
				end
			elseif not countOnly then
				table.insert(out, if lineNumber then `{index}:{line}` else line)
			end

			if maxCount and count >= maxCount then
				break
			end
		end
	end

	if countOnly then
		if count > 0 then
			return 0, tostring(count), ""
		end
		return 1, tostring(count), ""
	end

	if (after > 0 or before > 0) and not onlyMatching then
		local included = {}
		for index in selected do
			for i = math.max(1, index - before), math.min(#lines, index + after) do
				included[i] = true
			end
		end

		local contextual = {}
		local last = 0
		for index = 1, #lines do
			if included[index] then
				if last > 0 and index > last + 1 then
					table.insert(contextual, "--")
				end
				table.insert(contextual, if lineNumber then `{index}:{lines[index]}` else lines[index])
				last = index
			end
		end

		if #contextual > 0 then
			return 0, table.concat(contextual, "\n"), ""
		end
		return 1, "", ""
	end

	if count > 0 then
		return 0, table.concat(out, "\n"), ""
	end
	return 1, "", ""
end

return Grep
