local function parseDuration(text: string): number?
	local total = 0
	local hasMatch = false
	for num, unit in string.gmatch(string.lower(text), "(%d+%.?%d*)%s*([a-z]+)") do
		hasMatch = true
		local n = tonumber(num)
		if not n then return nil end
		if unit == "d" then total += n * 86400
		elseif unit == "h" then total += n * 3600
		elseif unit == "m" then total += n * 60
		elseif unit == "s" then total += n
		elseif unit == "mo" then total += n * 2592000
		elseif unit == "y" then total += n * 31536000
		end
	end
	if not hasMatch then
		local n = tonumber(text)
		if n then return n end
		return nil
	end
	return total
end

return {
	Validate = function(text: string, executor: Player)
		local val = parseDuration(text)
		if val ~= nil then
			return true
		end
		return false, `'{text}' is not a valid duration (e.g. 1d, 2h 30m, 1mo, 1y)`
	end,

	Transform = function(text: string, executor: Player)
		return parseDuration(text)
	end,

	Autocomplete = function(text: string, executor: Player, terminalService: any)
		local predefined = {
			{ Text = "1m", Description = "1 Minute" },
			{ Text = "5m", Description = "5 Minutes" },
			{ Text = "10m", Description = "10 Minutes" },
			{ Text = "30m", Description = "30 Minutes" },
			{ Text = "1h", Description = "1 Hour" },
			{ Text = "6h", Description = "6 Hours" },
			{ Text = "12h", Description = "12 Hours" },
			{ Text = "1d", Description = "1 Day" },
			{ Text = "7d", Description = "1 Week" },
			{ Text = "1mo", Description = "1 Month" },
			{ Text = "1y", Description = "1 Year" },
			{ Text = "10y", Description = "10 Years" },
		}

		local suggestions = {}

		if text and text ~= "" then
			for _, item in predefined do
				local score = terminalService.FuzzyMatch(text, item.Text)
				if score > 0 then
					table.insert(suggestions, { Text = item.Text, Description = item.Description, Score = score })
				end
			end
			table.sort(suggestions, function(a, b) return (a.Score or 0) > (b.Score or 0) end)

			local d = parseDuration(text)
			if d then
				-- Insert the exact matched value at the top if it's not already there
				table.insert(suggestions, 1, { Text = text, Description = `{d} seconds`, Score = 100 })
			end
		else
			suggestions = predefined
		end

		return suggestions
	end
}
