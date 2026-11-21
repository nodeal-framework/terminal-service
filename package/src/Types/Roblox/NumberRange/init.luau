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
	Argument type `NumberRange`: validates, transforms and autocompletes input
	typed into the terminal.
]=]

local UserInputService = game:GetService("UserInputService")

return {
	--[=[
		Validates raw terminal input for this type.

		@param text The text typed by the player.
		@param executor The player running the command.
		@return True when the text is valid, plus an error message otherwise.
	]=]
	Validate = function(text: string, executor: Player)
		local minimum, maximum = string.match(text, "^([^,]+),([^,]+)$")
		if minimum and maximum and tonumber(minimum) and tonumber(maximum) then
			return true
		end
		local single = string.match(text, "^([^,]+)$")
		if single and tonumber(single) then
			return true
		end
		return false, "Format must be Min, Max or Value"
	end,

	--[=[
		Converts validated text into the value the command receives.

		@param text The validated text.
		@param executor The player running the command.
		@return The typed value.
	]=]
	Transform = function(text: string, executor: Player)
		local minimum, maximum = string.match(text, "^([^,]+),([^,]+)$")
		if minimum and maximum then
			return NumberRange.new(tonumber(minimum), tonumber(maximum))
		end
		local single = string.match(text, "^([^,]+)$")
		if single then
			return NumberRange.new(tonumber(single))
		end
		return NumberRange.new(0)
	end,

	--[=[
		Returns completion candidates for partially typed text.

		@param text The text typed so far.
		@param executor The player running the command.
		@return The list of suggestions.
	]=]
	Autocomplete = function(text: string, executor: Player)
		return {}
	end,

	--[=[
		Builds the interactive picker shown in the autocomplete dropdown.

		@param currentText The text typed so far.
		@param terminalService The terminal service.
		@param onSelect Called with the chosen value.
		@param keepFocus Keeps the terminal input focused.
		@param liveUpdate Called while the selection changes.
		@return The picker frame.
	]=]
	CreateCustomUI = function(
		currentText: string,
		terminalService: any,
		onSelect: (string) -> (),
		keepFocus: () -> (),
		liveUpdate: (string) -> ()
	)
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
		local minimum, maximum = string.match(currentText, "^([^,]+),([^,]+)$")
		if minimum and maximum and tonumber(minimum) and tonumber(maximum) then
			cMin, cMax = tonumber(minimum), tonumber(maximum)
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

		--[=[
			Maps a number-range value to a 0..1 slider position.

			@param value The value to inspect.

			@return The slider position from 0 to 1.
		]=]
		local function getAlpha(value)
			return math.clamp(value / 100, 0, 1) -- default range 0-100 for ui
		end

		--[=[
			Refreshes the slider knobs from the current range.
		]=]
		local function updateVisuals()
			local aMin = getAlpha(cMin)
			local aMax = getAlpha(cMax)
			if aMin > aMax then
				aMin, aMax = aMax, aMin
			end

			KnobMin.Position = UDim2.new(aMin, 0, 0.5, 0)
			KnobMax.Position = UDim2.new(aMax, 0, 0.5, 0)
			Fill.Position = UDim2.new(aMin, 0, 0, 0)
			Fill.Size = UDim2.new(aMax - aMin, 0, 1, 0)
			Title.Text = string.format("Range: %.1f - %.1f", cMin, cMax)
		end
		updateVisuals()

		local draggingKnob = nil
		local connections = {}

		--[=[
			Updates the range from a pointer input.

			@param input The input to process.
		]=]
		local function onInput(input)
			local alpha = math.clamp(
				(input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X,
				0,
				1
			)
			local value = math.floor(alpha * 1000) / 10

			if draggingKnob == "min" then
				cMin = value
				if cMin > cMax then
					cMin = cMax
				end
			elseif draggingKnob == "max" then
				cMax = value
				if cMax < cMin then
					cMax = cMin
				end
			end
			updateVisuals()
			liveUpdate(string.format("%.1f,%.1f", cMin, cMax))
			keepFocus()
		end

		table.insert(
			connections,
			KnobMin.InputBegan:Connect(function(input)
				if
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				then
					draggingKnob = "min"
				end
			end)
		)
		table.insert(
			connections,
			KnobMax.InputBegan:Connect(function(input)
				if
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				then
					draggingKnob = "max"
				end
			end)
		)

		table.insert(
			connections,
			UserInputService.InputChanged:Connect(function(input)
				if
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				then
					if draggingKnob then
						onInput(input)
					end
				end
			end)
		)

		table.insert(
			connections,
			UserInputService.InputEnded:Connect(function(input)
				if
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				then
					if draggingKnob then
						draggingKnob = nil
						keepFocus()
					end
				end
			end)
		)

		Frame.Destroying:Connect(function()
			for _, connection in ipairs(connections) do
				connection:Disconnect()
			end
		end)

		return Frame
	end,
}
