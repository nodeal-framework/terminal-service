local function getDaysInMonth(month: number, year: number)
	if month == 2 then
		if year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0) then return 29 else return 28 end
	elseif month == 4 or month == 6 or month == 9 or month == 11 then
		return 30
	else
		return 31
	end
end

local function getFirstDayOfWeek(month: number, year: number)
	-- Zeller's congruence
	local q = 1
	local m = month
	local y = year
	if m < 3 then
		m += 12
		y -= 1
	end
	local k = y % 100
	local j = math.floor(y / 100)
	local h = (q + math.floor(13*(m+1)/5) + k + math.floor(k/4) + math.floor(j/4) - 2*j) % 7
	-- h is 0=Sat, 1=Sun, 2=Mon... We want 1=Mon, 7=Sun
	local res = ((h + 5) % 7) + 1
	return res
end

return {
	Validate = function(text: string, executor: Player)
		local d, m, y = string.match(text, "^(%d%d)/(%d%d)/(%d%d%d%d)$")
		if d and m and y then
			local day, month, year = tonumber(d), tonumber(m), tonumber(y)
			if month >= 1 and month <= 12 and day >= 1 and day <= getDaysInMonth(month, year) then
				return true
			end
			return false, `Invalid date '{text}'`
		end
		return false, "Format must be DD/MM/YYYY"
	end,

	Transform = function(text: string, executor: Player)
		local d, m, y = string.match(text, "^(%d%d)/(%d%d)/(%d%d%d%d)$")
		if d and m and y then
			return DateTime.fromLocalTime(tonumber(y), tonumber(m), tonumber(d), 0, 0, 0, 0)
		end
		return DateTime.now()
	end,

	Autocomplete = function(text: string, executor: Player)
		return {}
	end,

	CreateCustomUI = function(currentText: string, terminalService: any, onSelect: (string) -> (), keepFocus: () -> ())
		local Frame = Instance.new("Frame")
		Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		Frame.BorderSizePixel = 0
		Frame.Size = UDim2.new(1, -20, 0, 210)

		local Padding = Instance.new("UIPadding")
		Padding.PaddingTop = UDim.new(0, 10)
		Padding.PaddingBottom = UDim.new(0, 10)
		Padding.PaddingLeft = UDim.new(0, 10)
		Padding.PaddingRight = UDim.new(0, 10)
		Padding.Parent = Frame

		local Header = Instance.new("Frame")
		Header.BackgroundTransparency = 1
		Header.Size = UDim2.new(1, 0, 0, 25)
		Header.Parent = Frame

		local Title = Instance.new("TextLabel")
		Title.BackgroundTransparency = 1
		Title.Size = UDim2.new(1, 0, 1, 0)
		Title.Font = Enum.Font.SourceSansBold
		Title.TextSize = 18
		Title.TextColor3 = Color3.fromRGB(255, 255, 255)
		Title.Parent = Header

		local Grid = Instance.new("Frame")
		Grid.BackgroundTransparency = 1
		Grid.Position = UDim2.new(0, 0, 0, 35)
		Grid.Size = UDim2.new(1, 0, 1, -35)
		Grid.Parent = Frame

		local UIGridLayout = Instance.new("UIGridLayout")
		UIGridLayout.CellSize = UDim2.new(1/7, -5, 0, 22)
		UIGridLayout.CellPadding = UDim2.new(0, 5, 0, 5)
		UIGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
		UIGridLayout.Parent = Grid

		local days = {"Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"}
		for i, d in ipairs(days) do
			local lbl = Instance.new("TextLabel")
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.SourceSansSemibold
			lbl.TextSize = 14
			lbl.TextColor3 = Color3.fromRGB(150, 150, 150)
			lbl.Text = d
			lbl.LayoutOrder = i
			lbl.Parent = Grid
		end

		local date = os.date("*t")
		local curMonth = date.month
		local curYear = date.year
		local targetDay = nil

		local d, m, y = string.match(currentText, "^(%d%d?)/(%d%d?)/?(%d*)$")
		if d and m then
			targetDay = tonumber(d)
			local monthNum = tonumber(m)
			if monthNum > 0 then
				curMonth = math.clamp(monthNum, 1, 12)
			end
			if y and #y == 4 then
				curYear = tonumber(y)
			end
		else
			local d3 = string.match(currentText, "^(%d%d?)/?$")
			if d3 then
				targetDay = tonumber(d3)
			end
		end

		local dayButtons = {}

		local function renderMonth()
			for _, btn in ipairs(dayButtons) do
				btn:Destroy()
			end
			table.clear(dayButtons)

			Title.Text = `{curMonth}/{curYear}`

			local firstDay = getFirstDayOfWeek(curMonth, curYear)
			local daysInMonth = getDaysInMonth(curMonth, curYear)

			-- empty spaces before 1st
			for i = 1, firstDay - 1 do
				local empty = Instance.new("Frame")
				empty.BackgroundTransparency = 1
				empty.LayoutOrder = 10 + i
				empty.Parent = Grid
				table.insert(dayButtons, empty)
			end

			for day = 1, daysInMonth do
				local btn = Instance.new("TextButton")
				btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
				btn.BorderSizePixel = 0
				btn.Font = Enum.Font.Code
				btn.TextSize = 14
				btn.TextColor3 = Color3.fromRGB(255, 255, 255)
				btn.Text = tostring(day)

				if targetDay and day == targetDay then
					local stroke = Instance.new("UIStroke")
					stroke.Color = Color3.fromRGB(255, 255, 255)
					stroke.Thickness = 1
					stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
					stroke.Parent = btn
				end

				btn.LayoutOrder = 10 + firstDay - 1 + day
				btn.Parent = Grid

				btn.MouseButton1Down:Connect(function()
					onSelect(string.format("%02d/%02d/%04d", day, curMonth, curYear))
				end)

				table.insert(dayButtons, btn)
			end
		end

		local Prev = Instance.new("TextButton")
		Prev.BackgroundTransparency = 1
		Prev.Size = UDim2.new(0, 25, 1, 0)
		Prev.Text = "<"
		Prev.TextColor3 = Color3.fromRGB(255, 255, 255)
		Prev.Font = Enum.Font.SourceSansBold
		Prev.TextSize = 18
		Prev.Parent = Header
		Prev.MouseButton1Down:Connect(function()
			curMonth -= 1
			if curMonth < 1 then curMonth = 12; curYear -= 1 end
			renderMonth()
			keepFocus()
		end)

		local Next = Instance.new("TextButton")
		Next.BackgroundTransparency = 1
		Next.Size = UDim2.new(0, 25, 1, 0)
		Next.Position = UDim2.new(1, -25, 0, 0)
		Next.Text = ">"
		Next.TextColor3 = Color3.fromRGB(255, 255, 255)
		Next.Font = Enum.Font.SourceSansBold
		Next.TextSize = 18
		Next.Parent = Header
		Next.MouseButton1Down:Connect(function()
			curMonth += 1
			if curMonth > 12 then curMonth = 1; curYear += 1 end
			renderMonth()
			keepFocus()
		end)

		renderMonth()
		return Frame
	end
}
