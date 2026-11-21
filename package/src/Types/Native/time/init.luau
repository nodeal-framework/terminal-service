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
	Argument type `time`: validates, transforms and autocompletes input typed
	into the terminal.
]=]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

return {
	--[=[
		Validates raw terminal input for this type.

		@param text The text typed by the player.
		@param executor The player running the command.
		@return True when the text is valid, plus an error message otherwise.
	]=]
	Validate = function(text: string, executor: Player)
		local h, m = string.match(text, "^(%d%d):(%d%d)$")
		if h and m then
			local hour, minimum = tonumber(h), tonumber(m)
			if hour >= 0 and hour <= 23 and minimum >= 0 and minimum <= 59 then
				return true
			end
			return false, `Invalid time '{text}'`
		end
		return false, "Format must be HH:MM"
	end,

	--[=[
		Converts validated text into the value the command receives.

		@param text The validated text.
		@param executor The player running the command.
		@return The typed value.
	]=]
	Transform = function(text: string, executor: Player)
		return text
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

		--[=[
			Sets the time from a 0..1 position on the slider.

			@param alpha The slider position from 0 to 1.
		]=]
		local function updateTimeFromAlpha(alpha: number)
			alpha = math.clamp(alpha, 0, 1)
			local totalMinutes = math.floor(alpha * (24 * 60 - 1))
			local hour = math.floor(totalMinutes / 60)
			local minimum = totalMinutes % 60

			local timeStr = string.format("%02d:%02d", hour, minimum)
			ValueDisplay.Text = timeStr
			Fill.Size = UDim2.new(alpha, 0, 1, 0)
			Knob.Position = UDim2.new(alpha, 0, 0.5, 0)

			return timeStr
		end

		local h, m = string.match(currentText, "^(%d%d?):(%d%d?)$")
		if not (h and m) then
			h = string.match(currentText, "^(%d%d?):?$")
			if h then
				m = "00"
			end
		end
		if h and m then
			local hour, minimum = tonumber(h), tonumber(m)
			if hour >= 0 and hour <= 23 and minimum >= 0 and minimum <= 59 then
				local totalMinutes = (hour * 60) + minimum
				local alpha = totalMinutes / (24 * 60 - 1)
				updateTimeFromAlpha(alpha)
			end
		end

		--[=[
			Updates the time from a pointer input.

			@param input The input to process.
		]=]
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

		table.insert(
			connections,
			Knob.InputBegan:Connect(function(input)
				if
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				then
					isDragging = true
					keepFocus()
				end
			end)
		)

		table.insert(
			connections,
			Track.InputBegan:Connect(function(input)
				if
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				then
					isDragging = true
					onInput(input)
				end
			end)
		)

		table.insert(
			connections,
			UserInputService.InputChanged:Connect(function(input)
				if isDragging then
					onInput(input)
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
					if isDragging then
						isDragging = false
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
