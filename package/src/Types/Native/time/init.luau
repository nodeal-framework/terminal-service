local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

return {
	Validate = function(text: string, executor: Player)
		local h, m = string.match(text, "^(%d%d):(%d%d)$")
		if h and m then
			local hour, min = tonumber(h), tonumber(m)
			if hour >= 0 and hour <= 23 and min >= 0 and min <= 59 then
				return true
			end
			return false, `Invalid time '{text}'`
		end
		return false, "Format must be HH:MM"
	end,

	Transform = function(text: string, executor: Player)
		return text
	end,

	Autocomplete = function(text: string, executor: Player)
		return {}
	end,

	CreateCustomUI = function(currentText: string, terminalService: any, onSelect: (string) -> (), keepFocus: () -> (), liveUpdate: (string) -> ())
		local Frame = Instance.new("Frame")
		Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		Frame.BorderSizePixel = 0
		Frame.Size = UDim2.new(1, -20, 0, 70)

		local Padding = Instance.new("UIPadding")
		Padding.PaddingTop = UDim.new(0, 10)
		Padding.PaddingBottom = UDim.new(0, 10)
		Padding.PaddingLeft = UDim.new(0, 15)
		Padding.PaddingRight = UDim.new(0, 15)
		Padding.Parent = Frame

		local Header = Instance.new("Frame")
		Header.BackgroundTransparency = 1
		Header.Size = UDim2.new(1, 0, 0, 20)
		Header.Parent = Frame

		local Title = Instance.new("TextLabel")
		Title.BackgroundTransparency = 1
		Title.Size = UDim2.new(0, 100, 1, 0)
		Title.Font = Enum.Font.SourceSansSemibold
		Title.TextSize = 16
		Title.TextColor3 = Color3.fromRGB(150, 150, 150)
		Title.TextXAlignment = Enum.TextXAlignment.Left
		Title.Text = "Time of Day"
		Title.Parent = Header

		local ValueDisplay = Instance.new("TextLabel")
		ValueDisplay.BackgroundTransparency = 1
		ValueDisplay.Size = UDim2.new(0, 100, 1, 0)
		ValueDisplay.Position = UDim2.new(1, -100, 0, 0)
		ValueDisplay.Font = Enum.Font.Code
		ValueDisplay.TextSize = 18
		ValueDisplay.TextColor3 = Color3.fromRGB(255, 255, 255)
		ValueDisplay.TextXAlignment = Enum.TextXAlignment.Right
		ValueDisplay.Text = "12:00"
		ValueDisplay.Parent = Header

		local Track = Instance.new("Frame")
		Track.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		Track.BorderSizePixel = 0
		Track.Size = UDim2.new(1, 0, 0, 6)
		Track.Position = UDim2.new(0, 0, 1, -10)
		Track.AnchorPoint = Vector2.new(0, 1)
		Track.Parent = Frame

		local TrackCorner = Instance.new("UICorner")
		TrackCorner.CornerRadius = UDim.new(1, 0)
		TrackCorner.Parent = Track

		local Fill = Instance.new("Frame")
		Fill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
		Fill.BorderSizePixel = 0
		Fill.Size = UDim2.new(0.5, 0, 1, 0)
		Fill.Parent = Track

		local FillCorner = Instance.new("UICorner")
		FillCorner.CornerRadius = UDim.new(1, 0)
		FillCorner.Parent = Fill

		local Knob = Instance.new("TextButton")
		Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		Knob.BorderSizePixel = 0
		Knob.Size = UDim2.new(0, 16, 0, 16)
		Knob.AnchorPoint = Vector2.new(0.5, 0.5)
		Knob.Position = UDim2.new(0.5, 0, 0.5, 0)
		Knob.Text = ""
		Knob.Parent = Track

		local KnobCorner = Instance.new("UICorner")
		KnobCorner.CornerRadius = UDim.new(1, 0)
		KnobCorner.Parent = Knob

		local isDragging = false
		local connections = {}

		local function updateTimeFromAlpha(alpha: number)
			alpha = math.clamp(alpha, 0, 1)
			local totalMinutes = math.floor(alpha * (24 * 60 - 1))
			local hour = math.floor(totalMinutes / 60)
			local min = totalMinutes % 60

			local timeStr = string.format("%02d:%02d", hour, min)
			ValueDisplay.Text = timeStr
			Fill.Size = UDim2.new(alpha, 0, 1, 0)
			Knob.Position = UDim2.new(alpha, 0, 0.5, 0)

			return timeStr
		end

		-- Try to parse currentText to set initial position
		local h, m = string.match(currentText, "^(%d%d?):(%d%d?)$")
		if not (h and m) then
			h = string.match(currentText, "^(%d%d?):?$")
			if h then
				m = "00"
			end
		end
		if h and m then
			local hour, min = tonumber(h), tonumber(m)
			if hour >= 0 and hour <= 23 and min >= 0 and min <= 59 then
				local totalMinutes = (hour * 60) + min
				local alpha = totalMinutes / (24 * 60 - 1)
				updateTimeFromAlpha(alpha)
			end
		end

		local function onInput(input)
			local trackStart = Track.AbsolutePosition.X
			local trackWidth = Track.AbsoluteSize.X
			local mouseX = input.Position.X
			local alpha = (mouseX - trackStart) / trackWidth

			local timeStr = updateTimeFromAlpha(alpha)
			if liveUpdate then
				liveUpdate(timeStr)
			end
			keepFocus()
		end

		table.insert(connections, Knob.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				isDragging = true
				keepFocus()
			end
		end))

		table.insert(connections, Track.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				isDragging = true
				onInput(input)
			end
		end))

		table.insert(connections, UserInputService.InputChanged:Connect(function(input)
			if isDragging then
				onInput(input)
			end
		end))

		table.insert(connections, UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				if isDragging then
					isDragging = false
					keepFocus()
				end
			end
		end))

		Frame.Destroying:Connect(function()
			for _, conn in ipairs(connections) do
				conn:Disconnect()
			end
		end)

		return Frame
	end
}
