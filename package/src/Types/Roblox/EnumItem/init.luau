return {
	Validate = function(text: string, executor: Player, terminalService: any, argSpec: any)
		local specificEnum = (argSpec and type(argSpec.Enum) == "userdata") and argSpec.Enum or nil

		local parts = string.split(text, ".")
		local targetEnumCat = nil
		local targetItemName = nil

		if specificEnum then
			targetEnumCat = specificEnum
			targetItemName = parts[#parts]
		else
			if #parts == 2 then
				targetItemName = parts[2]
				for _, enumCat in Enum:GetEnums() do
					if string.lower(tostring(enumCat)) == string.lower(parts[1]) then
						targetEnumCat = enumCat
						break
					end
				end
			elseif #parts == 3 and string.lower(parts[1]) == "enum" then
				targetItemName = parts[3]
				for _, enumCat in Enum:GetEnums() do
					if string.lower(tostring(enumCat)) == string.lower(parts[2]) then
						targetEnumCat = enumCat
						break
					end
				end
			end
		end

		if targetEnumCat and targetItemName then
			local lowerItem = string.lower(targetItemName)
			for _, item in targetEnumCat:GetEnumItems() do
				if string.lower(item.Name) == lowerItem then
					return true
				end
			end
		end
		return false, "Invalid EnumItem"
	end,

	Transform = function(text: string, executor: Player, terminalService: any, argSpec: any)
		local specificEnum = (argSpec and type(argSpec.Enum) == "userdata") and argSpec.Enum or nil

		local parts = string.split(text, ".")
		local targetEnumCat = nil
		local targetItemName = nil

		if specificEnum then
			targetEnumCat = specificEnum
			targetItemName = parts[#parts]
		else
			if #parts == 2 then
				targetItemName = parts[2]
				for _, enumCat in Enum:GetEnums() do
					if string.lower(tostring(enumCat)) == string.lower(parts[1]) then
						targetEnumCat = enumCat
						break
					end
				end
			elseif #parts == 3 and string.lower(parts[1]) == "enum" then
				targetItemName = parts[3]
				for _, enumCat in Enum:GetEnums() do
					if string.lower(tostring(enumCat)) == string.lower(parts[2]) then
						targetEnumCat = enumCat
						break
					end
				end
			end
		end

		if targetEnumCat and targetItemName then
			local lowerItem = string.lower(targetItemName)
			for _, item in targetEnumCat:GetEnumItems() do
				if string.lower(item.Name) == lowerItem then
					return item
				end
			end
		end
		return nil
	end,

	Autocomplete = function(text: string, executor: Player, terminalService: any, argSpec: any)
		local specificEnum = (argSpec and type(argSpec.Enum) == "userdata") and argSpec.Enum or nil
		local suggestions = {}

		if specificEnum then
			local justName = tostring(specificEnum)
			for _, item in specificEnum:GetEnumItems() do
				local name1 = item.Name
				local name2 = justName .. "." .. item.Name
				local name3 = "Enum." .. justName .. "." .. item.Name

				local score1 = terminalService.FuzzyMatch(text, name1)
				local score2 = terminalService.FuzzyMatch(text, name2)
				local score3 = terminalService.FuzzyMatch(text, name3)
				local bestScore = math.max(score1, score2, score3)

				if bestScore > 0 then
					local bestText = score1 >= score2 and (score1 >= score3 and name1 or name3) or (score2 >= score3 and name2 or name3)
					table.insert(suggestions, { Text = bestText, Description = tostring(item.Value), Score = bestScore })
				end
			end
		else
			local parts = string.split(text, ".")
			if #parts == 1 then
				local sEnum = terminalService.FuzzyMatch(text, "Enum")
				if sEnum > 0 then table.insert(suggestions, { Text = "Enum", Description = "Roblox Enums", Score = sEnum }) end

				local dedup = {}
				for _, enumCat in Enum:GetEnums() do
					local justName = tostring(enumCat)
					local score = terminalService.FuzzyMatch(text, justName)
					if score > 0 and not dedup[justName] then
						dedup[justName] = true
						table.insert(suggestions, { Text = justName, Description = "Enum Category", Score = score })
					end
				end
			elseif #parts == 2 then
				if string.lower(parts[1]) == "enum" then
					local query = parts[2]
					local dedup = {}
					for _, enumCat in Enum:GetEnums() do
						local justName = tostring(enumCat)
						local score = terminalService.FuzzyMatch(query, justName)
						if score > 0 and not dedup[justName] then
							dedup[justName] = true
							table.insert(suggestions, { Text = "Enum." .. justName, Description = "Enum Category", Score = score })
						end
					end
				else
					local catQuery = parts[1]
					local itemQuery = parts[2]
					for _, enumCat in Enum:GetEnums() do
						local justName = tostring(enumCat)
						local catScore = terminalService.FuzzyMatch(catQuery, justName)
						if catScore > 50 then
							for _, item in enumCat:GetEnumItems() do
								local score = terminalService.FuzzyMatch(itemQuery, item.Name)
								if score > 0 then
									table.insert(suggestions, { Text = justName .. "." .. item.Name, Description = tostring(item.Value), Score = (catScore + score) / 2 })
								end
							end
						end
					end
				end
			elseif #parts == 3 then
				if string.lower(parts[1]) == "enum" then
					local catQuery = parts[2]
					local itemQuery = parts[3]
					for _, enumCat in Enum:GetEnums() do
						local justName = tostring(enumCat)
						local catScore = terminalService.FuzzyMatch(catQuery, justName)
						if catScore > 50 then
							for _, item in enumCat:GetEnumItems() do
								local score = terminalService.FuzzyMatch(itemQuery, item.Name)
								if score > 0 then
									table.insert(suggestions, { Text = "Enum." .. justName .. "." .. item.Name, Description = tostring(item.Value), Score = (catScore + score) / 2 })
								end
							end
						end
					end
				end
			end
		end

		local unique = {}
		local finalSuggestions = {}
		for _, s in suggestions do
			if not unique[s.Text] then
				unique[s.Text] = true
				table.insert(finalSuggestions, s)
			end
		end
		return finalSuggestions
	end
}
