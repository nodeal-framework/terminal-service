local UserInputService = game:GetService("UserInputService")

return {
	Validate = function(text: string, executor: Player)
		local min, max = string.match(text, "^([^,]+),([^,]+)$")
		if min and max and tonumber(min) and tonumber(max) then
			return true
		end
		local single = string.match(text, "^([^,]+)$")
		if single and tonumber(single) then return true end
		return false, "Format must be Min, Max or Value"
	end,

	Transform = function(text: string, executor: Player)
		local min, max = string.match(text, "^([^,]+),([^,]+)$")
		if min and max then
			return NumberRange.new(tonumber(min), tonumber(max))
		end
		local single = string.match(text, "^([^,]+)$")
		if single then
			return NumberRange.new(tonumber(single))
		end
		return NumberRange.new(0)
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

		local Title = Instance.new("TextLabel")
		Title.BackgroundTransparency = 1
		Title.Size = UDim2.new(1, 0, 0, 20)
		Title.Font = Enum.Font.SourceSansSemibold
		Title.TextSize = 16
		Title.TextColor3 = Color3.fromRGB(150, 150, 150)
		Title.TextXAlignment = Enum.TextXAlignment.Left
		Title.Text = "NumberRange"
		Title.Parent = Frame

		local cMin, cMax = 0, 10
		local min, max = string.match(currentText, "^([^,]+),([^,]+)$")
		if min and max and tonumber(min) and tonumber(max) then
			cMin, cMax = tonumber(min), tonumber(max)
		else
			local single = string.match(currentText, "^([^,]+)$")
			if single and tonumber(single) then
				cMin, cMax = tonumber(single), tonumber(single)
			end
		end

		local Track = Instance.new("Frame")
		Track.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		Track.BorderSizePixel = 0
		Track.Size = UDim2.new(1, 0, 0, 6)
		Track.Position = UDim2.new(0, 0, 1, -10)
		Track.AnchorPoint = Vector2.new(0, 1)
		Track.Parent = Frame

		local Fill = Instance.new("Frame")
		Fill.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
		Fill.BorderSizePixel = 0
		Fill.Parent = Track

		local KnobMin = Instance.new("TextButton")
		KnobMin.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		KnobMin.Size = UDim2.new(0, 6, 0, 14)
		KnobMin.AnchorPoint = Vector2.new(0.5, 0.5)
		KnobMin.Text = ""
		KnobMin.Parent = Track
		local StrokeMin = Instance.new("UIStroke")
		StrokeMin.Color = Color3.fromRGB(100, 100, 100)
		StrokeMin.Parent = KnobMin

		local KnobMax = Instance.new("TextButton")
		KnobMax.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		KnobMax.Size = UDim2.new(0, 6, 0, 14)
		KnobMax.AnchorPoint = Vector2.new(0.5, 0.5)
		KnobMax.Text = ""
		KnobMax.Parent = Track
		local StrokeMax = Instance.new("UIStroke")
		StrokeMax.Color = Color3.fromRGB(100, 100, 100)
		StrokeMax.Parent = KnobMax

		local function getAlpha(val)
			return math.clamp(val / 100, 0, 1) -- default range 0-100 for ui
		end

		local function updateVisuals()
			local aMin = getAlpha(cMin)
			local aMax = getAlpha(cMax)
			if aMin > aMax then aMin, aMax = aMax, aMin end

			KnobMin.Position = UDim2.new(aMin, 0, 0.5, 0)
			KnobMax.Position = UDim2.new(aMax, 0, 0.5, 0)
			Fill.Position = UDim2.new(aMin, 0, 0, 0)
			Fill.Size = UDim2.new(aMax - aMin, 0, 1, 0)
			Title.Text = string.format("Range: %.1f - %.1f", cMin, cMax)
		end
		updateVisuals()

		local draggingKnob = nil
		local connections = {}

		local function onInput(input)
			local alpha = math.clamp((input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
			local val = math.floor(alpha * 1000) / 10

			if draggingKnob == "min" then
				cMin = val
				if cMin > cMax then cMin = cMax end
			elseif draggingKnob == "max" then
				cMax = val
				if cMax < cMin then cMax = cMin end
			end
			updateVisuals()
			liveUpdate(string.format("%.1f,%.1f", cMin, cMax))
			keepFocus()
		end

		table.insert(connections, KnobMin.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				draggingKnob = "min"
			end
		end))
		table.insert(connections, KnobMax.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				draggingKnob = "max"
			end
		end))

		table.insert(connections, UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				if draggingKnob then
					onInput(input)
				end
			end
		end))

		table.insert(connections, UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				if draggingKnob then
					draggingKnob = nil
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
