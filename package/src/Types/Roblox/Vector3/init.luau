local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

return {
	Validate = function(text: string, executor: Player)
		local x, y, z = string.match(text, "^([^,]+),([^,]+),([^,]+)$")
		if x and y and z then
			if tonumber(x) and tonumber(y) and tonumber(z) then
				return true
			end
		end
		return false, "Format must be X, Y, Z"
	end,

	Transform = function(text: string, executor: Player)
		local x, y, z = string.match(text, "^([^,]+),([^,]+),([^,]+)$")
		if x and y and z then
			return Vector3.new(tonumber(x), tonumber(y), tonumber(z))
		end
		return Vector3.zero
	end,

	Autocomplete = function(text: string, executor: Player)
		return {}
	end,

	CreateCustomUI = function(currentText: string, terminalService: any, onSelect: (string) -> (), keepFocus: () -> (), liveUpdate: (string) -> ())
		local Frame = Instance.new("Frame")
		Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		Frame.BorderSizePixel = 0
		Frame.Size = UDim2.new(1, -20, 0, 160)

		local Padding = Instance.new("UIPadding")
		Padding.PaddingTop = UDim.new(0, 10)
		Padding.PaddingBottom = UDim.new(0, 10)
		Padding.PaddingLeft = UDim.new(0, 10)
		Padding.PaddingRight = UDim.new(0, 10)
		Padding.Parent = Frame

		local currentX, currentY, currentZ = 0, 0, 0
		local x, y, z = string.match(currentText, "^([^,]+),([^,]+),([^,]+)$")
		if x and y and z and tonumber(x) and tonumber(y) and tonumber(z) then
			currentX = tonumber(x)
			currentY = tonumber(y)
			currentZ = tonumber(z)
		end

		local GridArea = Instance.new("Frame")
		GridArea.Size = UDim2.new(0, 140, 0, 140)
		GridArea.Position = UDim2.new(0, 0, 0, 0)
		GridArea.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		GridArea.Parent = Frame

		local GridStroke = Instance.new("UIStroke")
		GridStroke.Color = Color3.fromRGB(60, 60, 60)
		GridStroke.Parent = GridArea

		local GridCursor = Instance.new("Frame")
		GridCursor.Size = UDim2.new(0, 10, 0, 10)
		GridCursor.AnchorPoint = Vector2.new(0.5, 0.5)
		GridCursor.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		GridCursor.Parent = GridArea

		local YSliderArea = Instance.new("Frame")
		YSliderArea.Size = UDim2.new(0, 20, 0, 140)
		YSliderArea.Position = UDim2.new(0, 150, 0, 0)
		YSliderArea.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		YSliderArea.Parent = Frame

		local YStroke = Instance.new("UIStroke")
		YStroke.Color = Color3.fromRGB(60, 60, 60)
		YStroke.Parent = YSliderArea

		local YCursor = Instance.new("Frame")
		YCursor.Size = UDim2.new(1, 4, 0, 6)
		YCursor.AnchorPoint = Vector2.new(0.5, 0.5)
		YCursor.Position = UDim2.new(0.5, 0, 0.5, 0)
		YCursor.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		YCursor.Parent = YSliderArea

		local InfoLabel = Instance.new("TextLabel")
		InfoLabel.BackgroundTransparency = 1
		InfoLabel.Size = UDim2.new(1, -180, 1, 0)
		InfoLabel.Position = UDim2.new(0, 180, 0, 0)
		InfoLabel.Font = Enum.Font.Code
		InfoLabel.TextSize = 14
		InfoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
		InfoLabel.TextYAlignment = Enum.TextYAlignment.Top
		InfoLabel.Text = `X: {currentX}\nY: {currentY}\nZ: {currentZ}`
		InfoLabel.Parent = Frame

		local function getGridPos(val)
			return math.clamp((val + 100) / 200, 0, 1)
		end

		local function updateVisuals()
			GridCursor.Position = UDim2.new(getGridPos(currentX), 0, getGridPos(currentZ), 0)
			YCursor.Position = UDim2.new(0.5, 0, 1 - getGridPos(currentY), 0)
			InfoLabel.Text = string.format("X: %.1f\nY: %.1f\nZ: %.1f", currentX, currentY, currentZ)
		end
		updateVisuals()

		local isDraggingGrid = false
		local isDraggingY = false
		local connections = {}

		local function onInput(input, type)
			if type == "grid" then
				local x = math.clamp((input.Position.X - GridArea.AbsolutePosition.X) / GridArea.AbsoluteSize.X, 0, 1)
				local z = math.clamp((input.Position.Y - GridArea.AbsolutePosition.Y) / GridArea.AbsoluteSize.Y, 0, 1)
				currentX = math.floor((x * 200 - 100) * 10) / 10
				currentZ = math.floor((z * 200 - 100) * 10) / 10
			elseif type == "y" then
				local y = math.clamp((input.Position.Y - YSliderArea.AbsolutePosition.Y) / YSliderArea.AbsoluteSize.Y, 0, 1)
				currentY = math.floor(((1 - y) * 200 - 100) * 10) / 10
			end
			updateVisuals()
			liveUpdate(string.format("%.1f,%.1f,%.1f", currentX, currentY, currentZ))
			keepFocus()
		end

		table.insert(connections, GridArea.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				isDraggingGrid = true
				onInput(input, "grid")
			end
		end))

		table.insert(connections, YSliderArea.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				isDraggingY = true
				onInput(input, "y")
			end
		end))

		table.insert(connections, UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				if isDraggingGrid then
					onInput(input, "grid")
				elseif isDraggingY then
					onInput(input, "y")
				end
			end
		end))

		table.insert(connections, UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				if isDraggingGrid or isDraggingY then
					isDraggingGrid = false
					isDraggingY = false
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
