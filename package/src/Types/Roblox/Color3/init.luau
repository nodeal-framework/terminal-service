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
	Argument type `Color3`: validates, transforms and autocompletes input typed
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
		if string.match(text, "^#%x%x%x%x%x%x$") or string.match(text, "^%x%x%x%x%x%x$") then
			return true
		end
		local r, g, b = string.match(text, "^(%d+)%s*,%s*(%d+)%s*,%s*(%d+)$")
		if r and g and b then
			if tonumber(r) <= 255 and tonumber(g) <= 255 and tonumber(b) <= 255 then
				return true
			end
		end
		return false
	end,
	--[=[
		Converts validated text into the value the command receives.

		@param text The validated text.
		@param executor The player running the command.
		@return The typed value.
	]=]
	Transform = function(text: string, executor: Player)
		if string.match(text, "^#%x%x%x%x%x%x$") then
			return Color3.fromHex(string.sub(text, 2))
		elseif string.match(text, "^%x%x%x%x%x%x$") then
			return Color3.fromHex(text)
		end
		local r, g, b = string.match(text, "^(%d+)%s*,%s*(%d+)%s*,%s*(%d+)$")
		if r and g and b then
			return Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))
		end
		return Color3.new(1, 1, 1)
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
		terminalService,
		onSelect: (string) -> (),
		keepFocus: () -> (),
		liveUpdate: (string) -> ()
	)
		local Frame = Instance.new("Frame")
		Frame.Size = UDim2.new(1, 0, 0, 185)
		Frame.BackgroundTransparency = 1

		local currentH, currentS, currentV = 0, 1, 1

		local c
		if string.match(currentText, "^#%x%x%x%x%x%x$") then
			c = Color3.fromHex(string.sub(currentText, 2))
		elseif string.match(currentText, "^%x%x%x%x%x%x$") then
			c = Color3.fromHex(currentText)
		else
			local r, g, b = string.match(currentText, "^(%d+)%s*,%s*(%d+)%s*,%s*(%d+)$")
			if r and g and b then
				if tonumber(r) <= 255 and tonumber(g) <= 255 and tonumber(b) <= 255 then
					c = Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))
				end
			end
		end

		if c then
			currentH, currentS, currentV = c:ToHSV()
		end

		local SVPicker = Instance.new("Frame")
		SVPicker.Size = UDim2.new(0, 150, 0, 150)
		SVPicker.Position = UDim2.new(0, 10, 0, 10)
		SVPicker.BackgroundColor3 = Color3.fromHSV(currentH, 1, 1)
		SVPicker.BorderSizePixel = 0
		SVPicker.Parent = Frame

		local SatLayer = Instance.new("Frame")
		SatLayer.Size = UDim2.new(1, 0, 1, 0)
		SatLayer.BackgroundColor3 = Color3.new(1, 1, 1)
		SatLayer.BorderSizePixel = 0
		SatLayer.Parent = SVPicker
		local SatGrad = Instance.new("UIGradient")
		SatGrad.Transparency = NumberSequence.new(0, 1)
		SatGrad.Parent = SatLayer

		local ValLayer = Instance.new("Frame")
		ValLayer.Size = UDim2.new(1, 0, 1, 0)
		ValLayer.BackgroundColor3 = Color3.new(0, 0, 0)
		ValLayer.BorderSizePixel = 0
		ValLayer.Parent = SVPicker
		local ValGrad = Instance.new("UIGradient")
		ValGrad.Rotation = 90
		ValGrad.Transparency = NumberSequence.new(1, 0)
		ValGrad.Parent = ValLayer

		local SVKnob = Instance.new("Frame")
		SVKnob.Size = UDim2.new(0, 10, 0, 10)
		SVKnob.AnchorPoint = Vector2.new(0.5, 0.5)
		SVKnob.Position = UDim2.new(currentS, 0, 1 - currentV, 0)
		SVKnob.BackgroundColor3 = Color3.new(1, 1, 1)
		SVKnob.Parent = SVPicker
		local SVStroke = Instance.new("UIStroke")
		SVStroke.Color = Color3.new(0, 0, 0)
		SVStroke.Thickness = 1
		SVStroke.Parent = SVKnob

		local HuePicker = Instance.new("Frame")
		HuePicker.Size = UDim2.new(0, 150, 0, 15)
		HuePicker.Position = UDim2.new(0, 10, 0, 165)
		HuePicker.BackgroundColor3 = Color3.new(1, 1, 1)
		HuePicker.BorderSizePixel = 0
		HuePicker.Parent = Frame

		local HueGrad = Instance.new("UIGradient")
		HueGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
			ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
			ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)),
			ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
			ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)),
			ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
		})
		HueGrad.Parent = HuePicker

		local HueKnob = Instance.new("Frame")
		HueKnob.Size = UDim2.new(0, 6, 1, 4)
		HueKnob.AnchorPoint = Vector2.new(0.5, 0.5)
		HueKnob.Position = UDim2.new(currentH, 0, 0.5, 0)
		HueKnob.BackgroundColor3 = Color3.new(1, 1, 1)
		HueKnob.Parent = HuePicker
		local HueStroke = Instance.new("UIStroke")
		HueStroke.Color = Color3.new(0, 0, 0)
		HueStroke.Thickness = 1
		HueStroke.Parent = HueKnob

		local Preview = Instance.new("Frame")
		Preview.Size = UDim2.new(0, 60, 0, 60)
		Preview.Position = UDim2.new(0, 175, 0, 10)
		Preview.BackgroundColor3 = Color3.fromHSV(currentH, currentS, currentV)
		Preview.Parent = Frame
		local PrevStroke = Instance.new("UIStroke")
		PrevStroke.Color = Color3.fromRGB(60, 60, 60)
		PrevStroke.Thickness = 2
		PrevStroke.Parent = Preview

		local connections = {}
		local isDraggingSV = false
		local isDraggingHue = false

		--[=[
			Refreshes the colour preview and notifies live updates.

			@param callLiveUpdate Whether to notify live listeners.
		]=]
		local function updateColorInternal(callLiveUpdate)
			local c = Color3.fromHSV(currentH, currentS, currentV)
			Preview.BackgroundColor3 = c
			SVPicker.BackgroundColor3 = Color3.fromHSV(currentH, 1, 1)
			if callLiveUpdate then
				local hex = "#" .. c:ToHex()
				liveUpdate(hex)
			end
		end

		table.insert(
			connections,
			SVPicker.InputBegan:Connect(function(input)
				if
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				then
					isDraggingSV = true
					keepFocus()
					local x = math.clamp(
						(input.Position.X - SVPicker.AbsolutePosition.X) / SVPicker.AbsoluteSize.X,
						0,
						1
					)
					local y = math.clamp(
						(input.Position.Y - SVPicker.AbsolutePosition.Y) / SVPicker.AbsoluteSize.Y,
						0,
						1
					)
					currentS = x
					currentV = 1 - y
					SVKnob.Position = UDim2.new(x, 0, y, 0)
					updateColorInternal(true)
				end
			end)
		)

		table.insert(
			connections,
			HuePicker.InputBegan:Connect(function(input)
				if
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				then
					isDraggingHue = true
					keepFocus()
					local x = math.clamp(
						(input.Position.X - HuePicker.AbsolutePosition.X) / HuePicker.AbsoluteSize.X,
						0,
						1
					)
					currentH = x
					HueKnob.Position = UDim2.new(x, 0, 0.5, 0)
					updateColorInternal(true)
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
					if isDraggingSV then
						local x = math.clamp(
							(input.Position.X - SVPicker.AbsolutePosition.X)
								/ SVPicker.AbsoluteSize.X,
							0,
							1
						)
						local y = math.clamp(
							(input.Position.Y - SVPicker.AbsolutePosition.Y)
								/ SVPicker.AbsoluteSize.Y,
							0,
							1
						)
						currentS = x
						currentV = 1 - y
						SVKnob.Position = UDim2.new(x, 0, y, 0)
						updateColorInternal(true)
					elseif isDraggingHue then
						local x = math.clamp(
							(input.Position.X - HuePicker.AbsolutePosition.X)
								/ HuePicker.AbsoluteSize.X,
							0,
							1
						)
						currentH = x
						HueKnob.Position = UDim2.new(x, 0, 0.5, 0)
						updateColorInternal(true)
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
					if isDraggingSV or isDraggingHue then
						isDraggingSV = false
						isDraggingHue = false
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
