local Display = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local terminalGui
local mainFrame
local inputBar
local autocompleteDropdown

local lineTemplate
local entryFrame
local suggestTemplate
local titleTemplate
local descriptionTemplate

local isVisible = false
local terminalService
local commandHistory = {}
local historyIndex = 1
local activeSuggestions = {}
local selectedSuggestionIndex = 1
local suggestionButtons = {}
local expectedDropdownVisible = false
local currentActiveArgText = ""

local function getPrompt(isHtml: boolean)
	local playerName = localPlayer.Name
	if isHtml then
		return `<b><font color="#85e89d">{playerName}@roblox</font></b>:<font color="#79c0ff">~</font>$ `
	else
		return `{playerName}@roblox:~$ `
	end
end

local function createUI()
	local Terminal = Instance.new("ScreenGui")
	Terminal.DisplayOrder = 1000
	Terminal.Name = "Terminal"
	Terminal.ResetOnSpawn = false
	Terminal.AutoLocalize = false

	local Frame = Instance.new("ScrollingFrame")
	Frame.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
	Frame.BackgroundTransparency = 0.15
	Frame.BorderSizePixel = 0
	Frame.CanvasSize = UDim2.new(0, 0, 0, 0)
	Frame.Name = "Frame"
	Frame.Position = UDim2.new(0.025, 0, 0, 25)
	Frame.ScrollBarThickness = 6
	Frame.ScrollingDirection = Enum.ScrollingDirection.Y
	Frame.Selectable = false
	Frame.Size = UDim2.new(0.95, 0, 0, 0)
	Frame.Visible = false
	Frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	Frame.Parent = Terminal

	local Autocomplete = Instance.new("ScrollingFrame")
	Autocomplete.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	Autocomplete.BackgroundTransparency = 0.1
	Autocomplete.BorderSizePixel = 0


	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = Color3.fromRGB(60, 60, 60)
	uiStroke.Thickness = 1
	uiStroke.Parent = Autocomplete

	Autocomplete.CanvasSize = UDim2.new(0, 0, 0, 0)
	Autocomplete.Name = "Autocomplete"
	Autocomplete.Position = UDim2.new(0, 167, 0, 75)
	Autocomplete.ScrollBarThickness = 6
	Autocomplete.ScrollingDirection = Enum.ScrollingDirection.Y
	Autocomplete.Selectable = false
	Autocomplete.Size = UDim2.new(0, 200, 0, 200)
	Autocomplete.Visible = false
	Autocomplete.AutomaticCanvasSize = Enum.AutomaticSize.Y
	Autocomplete.Parent = Terminal

	local UIListLayout = Instance.new("UIListLayout")
	UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	UIListLayout.Parent = Frame

	local function getDesiredHeight()
		local contentH = UIListLayout.AbsoluteContentSize.Y
		local maxH = math.min(workspace.CurrentCamera.ViewportSize.Y * 0.25, 250)
		return math.min(contentH + 10, maxH) -- +10 for UIPaddingTop
	end

	UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		if isVisible then
			mainFrame.Size = UDim2.new(0.95, 0, 0, getDesiredHeight())
		end
	end)

	local UIPadding = Instance.new("UIPadding")
	UIPadding.PaddingLeft = UDim.new(0, 10)
	UIPadding.PaddingRight = UDim.new(0, 10)
	UIPadding.PaddingTop = UDim.new(0, 10)
	UIPadding.Parent = Frame

	local Entry = Instance.new("Frame")
	Entry.BackgroundTransparency = 1
	Entry.LayoutOrder = 999999999
	Entry.Name = "Entry"
	Entry.Size = UDim2.new(1, 0, 0, 20)
	Entry.Parent = Frame
	entryFrame = Entry

	local BottomPadding = Instance.new("Frame")
	BottomPadding.BackgroundTransparency = 1
	BottomPadding.LayoutOrder = 1000000000
	BottomPadding.Size = UDim2.new(1, 0, 0, 10)
	BottomPadding.Parent = Frame

	local UIListLayout2 = Instance.new("UIListLayout")
	UIListLayout2.SortOrder = Enum.SortOrder.LayoutOrder
	UIListLayout2.Padding = UDim.new(0, 2)
	UIListLayout2.Parent = Autocomplete

	local autoPadding = Instance.new("UIPadding")
	autoPadding.PaddingLeft = UDim.new(0, 5)
	autoPadding.PaddingRight = UDim.new(0, 5)
	autoPadding.PaddingTop = UDim.new(0, 5)
	autoPadding.PaddingBottom = UDim.new(0, 5)
	autoPadding.Parent = Autocomplete

	local Title = Instance.new("Frame")
	Title.BackgroundColor3 = Color3.fromRGB(59, 59, 59)
	Title.BackgroundTransparency = 1
	Title.BorderSizePixel = 0
	Title.LayoutOrder = -2
	Title.Name = "Title"
	Title.Size = UDim2.new(1, 0, 0, 40)

	local TitleLayout = Instance.new("UIListLayout")
	TitleLayout.FillDirection = Enum.FillDirection.Horizontal
	TitleLayout.SortOrder = Enum.SortOrder.LayoutOrder
	TitleLayout.Padding = UDim.new(0, 5)
	TitleLayout.Parent = Title

	local Description = Instance.new("Frame")
	Description.BackgroundColor3 = Color3.fromRGB(59, 59, 59)
	Description.BackgroundTransparency = 1
	Description.BorderSizePixel = 0
	Description.LayoutOrder = -1
	Description.Name = "Description"
	Description.Size = UDim2.new(1, 0, 0, 20)

	local TextButton = Instance.new("TextButton")
	TextButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	TextButton.BackgroundTransparency = 1
	TextButton.BorderSizePixel = 0
	TextButton.Font = Enum.Font.Code
	TextButton.Size = UDim2.new(1, 0, 0, 30)


	TextButton.Text = ""
	TextButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	TextButton.TextSize = 14
	TextButton.TextXAlignment = Enum.TextXAlignment.Left

	local UIListLayout3 = Instance.new("UIListLayout")
	UIListLayout3.FillDirection = Enum.FillDirection.Horizontal
	UIListLayout3.SortOrder = Enum.SortOrder.LayoutOrder
	UIListLayout3.Padding = UDim.new(0, 7)
	UIListLayout3.Parent = Entry

	local TextLabelPrompt = Instance.new("TextLabel")
	TextLabelPrompt.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	TextLabelPrompt.BackgroundTransparency = 1
	TextLabelPrompt.Font = Enum.Font.Code
	TextLabelPrompt.Size = UDim2.new(0, 0, 0, 20)
	TextLabelPrompt.AutomaticSize = Enum.AutomaticSize.X
	TextLabelPrompt.RichText = true
	TextLabelPrompt.Text = getPrompt(true)
	TextLabelPrompt.TextColor3 = Color3.fromRGB(200, 200, 200)
	TextLabelPrompt.TextSize = 14
	TextLabelPrompt.TextXAlignment = Enum.TextXAlignment.Left
	TextLabelPrompt.Parent = Entry

	local TextBox = Instance.new("TextBox")
	TextBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	TextBox.BackgroundTransparency = 1
	TextBox.ClearTextOnFocus = false
	TextBox.Font = Enum.Font.Code
	TextBox.LayoutOrder = 999999999
	TextBox.Position = UDim2.new(0, 140, 0, 0)
	TextBox.Size = UDim2.new(1, -200, 0, 20)
	TextBox.Text = ""
	TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
	TextBox.TextSize = 14
	TextBox.TextXAlignment = Enum.TextXAlignment.Left
	TextBox.Selectable = false
	TextBox.Parent = Entry
	inputBar = TextBox

	local Field = Instance.new("TextLabel")
	Field.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	Field.BackgroundTransparency = 1
	Field.Font = Enum.Font.SourceSansBold
	Field.Name = "Field"
	Field.Size = UDim2.new(0, 0, 1, 0)
	Field.AutomaticSize = Enum.AutomaticSize.X
	Field.RichText = true
	Field.Text = "from"
	Field.TextColor3 = Color3.fromRGB(255, 255, 255)
	Field.TextSize = 20
	Field.TextXAlignment = Enum.TextXAlignment.Left
	Field.Parent = Title

	local UIPadding2 = Instance.new("UIPadding")
	UIPadding2.PaddingLeft = UDim.new(0, 10)
	UIPadding2.Parent = Title

	local Label = Instance.new("TextLabel")
	Label.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	Label.BackgroundTransparency = 1
	Label.Font = Enum.Font.SourceSansLight
	Label.Name = "Label"
	Label.Size = UDim2.new(1, 0, 1, 0)
	Label.Text = "Description goes here"
	Label.TextColor3 = Color3.fromRGB(255, 255, 255)
	Label.TextSize = 16
	Label.TextWrapped = true
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.TextYAlignment = Enum.TextYAlignment.Top
	Label.Parent = Description

	local UIPadding3 = Instance.new("UIPadding")
	UIPadding3.PaddingBottom = UDim.new(0, 10)
	UIPadding3.PaddingLeft = UDim.new(0, 10)
	UIPadding3.PaddingRight = UDim.new(0, 10)
	UIPadding3.Parent = Description

	local Typed = Instance.new("TextLabel")
	Typed.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	Typed.BackgroundTransparency = 1
	Typed.Font = Enum.Font.Code
	Typed.Name = "Typed"
	Typed.Size = UDim2.new(1, 0, 1, 0)
	Typed.Text = "Lab"
	Typed.TextColor3 = Color3.fromRGB(131, 222, 255)
	Typed.TextSize = 14
	Typed.TextXAlignment = Enum.TextXAlignment.Left
	Typed.Parent = TextButton

	local UIPadding4 = Instance.new("UIPadding")
	UIPadding4.PaddingLeft = UDim.new(0, 10)
	UIPadding4.Parent = TextButton

	local Suggest = Instance.new("TextLabel")
	Suggest.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	Suggest.BackgroundTransparency = 1
	Suggest.Font = Enum.Font.Code
	Suggest.Name = "Suggest"
	Suggest.Size = UDim2.new(1, 0, 1, 0)
	Suggest.Text = "   el"
	Suggest.TextColor3 = Color3.fromRGB(255, 255, 255)
	Suggest.TextSize = 14
	Suggest.TextXAlignment = Enum.TextXAlignment.Left
	Suggest.Parent = TextButton
	-- RichText will handle the Type formatting


	titleTemplate = Title
	descriptionTemplate = Description
	suggestTemplate = TextButton

	terminalGui = Terminal
	mainFrame = Frame
	autocompleteDropdown = Autocomplete

	terminalGui.Parent = playerGui
end

local function printToConsole(text: string, color: Color3?, promptHtml: string?)
	local clearChunks = string.split(text, "\27[2J")
	if #clearChunks > 1 then
		for _, child in mainFrame:GetChildren() do
			if child.Name == "Line" then
				child:Destroy()
			end
		end
		text = clearChunks[#clearChunks]
		if string.sub(text, 1, 1) == "\n" then
			text = string.sub(text, 2)
		end
		if text == "" then return end
	end

	local lineFrame = Instance.new("Frame")
	lineFrame.BackgroundTransparency = 1
	lineFrame.Name = "Line"
	lineFrame.Size = UDim2.new(1, 0, 0, 20)
	lineFrame.AutomaticSize = Enum.AutomaticSize.Y

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = lineFrame

	if promptHtml then
		local p = Instance.new("TextLabel")
		p.BackgroundTransparency = 1
		p.Font = Enum.Font.Code
		p.TextSize = 14
		p.RichText = true
		p.Text = promptHtml
		p.TextColor3 = Color3.fromRGB(200, 200, 200)
		p.AutomaticSize = Enum.AutomaticSize.X
		p.Size = UDim2.new(0, 0, 0, 20)
		p.TextYAlignment = Enum.TextYAlignment.Top
		p.Parent = lineFrame
	end

	local content = Instance.new("TextBox")
	content.BackgroundTransparency = 1
	content.Font = Enum.Font.Code
	content.TextSize = 14
	content.Text = text
	content.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	content.TextXAlignment = Enum.TextXAlignment.Left
	content.TextYAlignment = Enum.TextYAlignment.Top
	content.TextEditable = false
	content.ClearTextOnFocus = false
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.Size = UDim2.new(1, promptHtml and -200 or 0, 0, 20)
	content.Parent = lineFrame

	lineFrame.Parent = mainFrame

	task.defer(function()
		mainFrame.CanvasPosition = Vector2.new(0, mainFrame.AbsoluteCanvasSize.Y)
	end)
end

local function closeSuggestions()
	expectedDropdownVisible = false
	autocompleteDropdown.Visible = false
	for _, child in autocompleteDropdown:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UIStroke") then
			child:Destroy()
		end
	end
	table.clear(suggestionButtons)
	activeSuggestions = {}
end

local function applySuggestion(suggestion: string)
	local currentText = inputBar.Text
	local argText = currentActiveArgText

	if argText ~= "" and string.sub(currentText, -#argText) == argText then
		currentText = string.sub(currentText, 1, #currentText - #argText)
	end

	inputBar.Text = currentText .. suggestion .. " "
	inputBar.CursorPosition = #inputBar.Text + 1
	closeSuggestions()
end

local function highlightSuggestion(index: number)
	selectedSuggestionIndex = index
	local targetBtn = nil
	for i, btn in ipairs(suggestionButtons) do
		if i == index then
			btn.BackgroundTransparency = 0.95
			targetBtn = btn
		else
			btn.BackgroundTransparency = 1
		end
	end

	if targetBtn and autocompleteDropdown:IsA("ScrollingFrame") then
		local btnTop = targetBtn.AbsolutePosition.Y
		local btnBottom = btnTop + targetBtn.AbsoluteSize.Y
		local viewTop = autocompleteDropdown.AbsolutePosition.Y
		local viewBottom = viewTop + autocompleteDropdown.AbsoluteWindowSize.Y

		if btnTop < viewTop then
			autocompleteDropdown.CanvasPosition = Vector2.new(
				0, 
				autocompleteDropdown.CanvasPosition.Y - (viewTop - btnTop)
			)
		elseif btnBottom > viewBottom then
			autocompleteDropdown.CanvasPosition = Vector2.new(
				0, 
				autocompleteDropdown.CanvasPosition.Y + (btnBottom - viewBottom)
			)
		end
	end
end

local function buildSignatureUI(cmdInfo, activeIndex)
	local title = titleTemplate:Clone()
	title.Visible = true
	title.Parent = autocompleteDropdown

	local templateField = title:FindFirstChild("Field")
	if templateField then
		templateField.Parent = nil

		local nameField = templateField:Clone()
		nameField.Text = cmdInfo.Name
		nameField.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameField.Parent = title

		for i, arg in ipairs(cmdInfo.Args) do
			local f = templateField:Clone()
			local argName = arg.Name or arg.name or "unknown"
			local argType = ": " .. (arg.Type or arg.type or "any")

			local r, g, b
			if i == activeIndex then
				r, g, b = 255, 255, 255
			else
				r, g, b = 150, 150, 150
			end

			f.TextSize = 17
			f.Text = string.format([[<font color="rgb(%d,%d,%d)">%s<font size="13" face="SourceSans">%s</font></font>]], r, g, b, argName, argType)
			f.Parent = title
		end
	end

	if cmdInfo.Description and cmdInfo.Description ~= "" then
		local desc = descriptionTemplate:Clone()
		desc.Label.Text = cmdInfo.Description
		desc.Visible = true
		desc.Parent = autocompleteDropdown
	end
end

local isLiveUpdating = false

local function liveUpdateSuggestion(suggestion: string)
	isLiveUpdating = true
	local currentText = inputBar.Text
	local argText = currentActiveArgText

	if argText ~= "" and string.sub(currentText, -#argText) == argText then
		currentText = string.sub(currentText, 1, #currentText - #argText)
	end

	inputBar.Text = currentText .. suggestion
	inputBar.CursorPosition = #inputBar.Text + 1

	currentActiveArgText = suggestion
	lastSuggestionText = inputBar.Text
	isLiveUpdating = false
end

local function updateSuggestions(forceRebuild)
	if not terminalService then return end
	if isLiveUpdating then return end

	local currentText = inputBar.Text
	currentText = string.gsub(currentText, "\t", "")

	if not forceRebuild and autocompleteDropdown.Visible and lastSuggestionText == currentText then
		return
	end
	lastSuggestionText = currentText

	local data = terminalService:GetAutocompleteSuggestions(currentText)
	local suggestions = data.Suggestions or {}
	local cmdInfo = data.CommandInfo
	local activeIndex = data.ActiveArgIndex or 1
	currentActiveArgText = data.CurrentArgText or ""

	for _, child in autocompleteDropdown:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UIStroke") then
			child:Destroy()
		end
	end
	table.clear(suggestionButtons)

	local titleWidth = 0
	if cmdInfo then
		buildSignatureUI(cmdInfo, activeIndex)

		local nameW = TextService:GetTextSize(cmdInfo.Name, 20, Enum.Font.SourceSansBold, Vector2.new(1000, 20)).X
		titleWidth = 10 + nameW
		for _, arg in ipairs(cmdInfo.Args) do
			local argName = arg.Name or arg.name or "unknown"
			local argType = ": " .. (arg.Type or arg.type or "any")
			local nW = TextService:GetTextSize(argName, 17, Enum.Font.SourceSansBold, Vector2.new(1000, 20)).X
			local tW = TextService:GetTextSize(argType, 13, Enum.Font.SourceSans, Vector2.new(1000, 20)).X
			titleWidth = titleWidth + 5 + nW + tW
		end
		titleWidth = titleWidth + 30

		-- Custom UI rendering for specific types
		local argSpec = cmdInfo.Args[activeIndex]
		if argSpec and data.ActiveArgType then
			local types = string.split(string.gsub(data.ActiveArgType, "%s+", ""), "|")

			if #types == 1 then
				local typeParser = terminalService:GetType(types[1])
				if typeParser and typeParser.CreateCustomUI then
					local customUI = typeParser.CreateCustomUI(
						data.CurrentArgText or "", 
						terminalService, 
						function(selectedText)
							applySuggestion(selectedText)
							task.defer(function() inputBar:CaptureFocus() end)
						end,
						function() -- keepFocus
							task.defer(function() inputBar:CaptureFocus() end)
						end,
						function(liveText) -- liveUpdate
							liveUpdateSuggestion(liveText)
						end,
						argSpec
					)

					if customUI then
						customUI.Parent = autocompleteDropdown
						expectedDropdownVisible = true
						autocompleteDropdown.Visible = true

						local uiHeight = 10
						local visibleItems = 0
						if cmdInfo ~= nil then 
							uiHeight += 40
							visibleItems += 1
						end
						if cmdInfo and cmdInfo.Description and cmdInfo.Description ~= "" then 
							uiHeight += 20
							visibleItems += 1
						end

						visibleItems += 1 -- CustomUI is an item
						if visibleItems > 1 then
							uiHeight += (visibleItems - 1) * 2
						end

						uiHeight += customUI.Size.Y.Offset

						autocompleteDropdown.Size = UDim2.new(0, math.max(300, titleWidth), 0, uiHeight)
						activeSuggestions = {}
						return
					end
				end
			end
		end
	end

	local visibleItems = 0
	local yHeight = 10
	if cmdInfo ~= nil then
		yHeight += 40
		visibleItems += 1
	end
	if cmdInfo and cmdInfo.Description and cmdInfo.Description ~= "" then
		yHeight += 20
		visibleItems += 1
	end
	if visibleItems > 1 then
		yHeight += (visibleItems - 1) * 2
	end

	if #suggestions == 0 then
		if not cmdInfo then
			closeSuggestions()
		else
			expectedDropdownVisible = true
			autocompleteDropdown.Visible = true
			autocompleteDropdown.Size = UDim2.new(0, math.max(300, titleWidth), 0, yHeight)
			activeSuggestions = {}
		end
		return
	end

	activeSuggestions = suggestions
	expectedDropdownVisible = true
	autocompleteDropdown.Visible = true
	selectedSuggestionIndex = 1

	local maxTextWidth = 100
	local maxDescWidth = 0
	for i, suggestion in ipairs(suggestions) do

		local btn = suggestTemplate:Clone()
		btn.Text = ""
		local displayString = suggestion.DisplayText or suggestion.Text
		btn.Typed.Text = displayString

		local iconOffset = 0
		if suggestion.Icon then
			iconOffset = 25
			local icon = Instance.new("ImageLabel")
			icon.BackgroundTransparency = 1
			icon.Size = UDim2.new(1, 0, 1, 0)
			icon.Position = UDim2.new(0, -10, 0.5, 0)
			icon.AnchorPoint = Vector2.new(0, 0.5)
			icon.Image = suggestion.Icon
			icon.ScaleType = Enum.ScaleType.Fit
			icon.Parent = btn

			local aspect = Instance.new("UIAspectRatioConstraint")
			aspect.AspectRatio = 1
			aspect.DominantAxis = Enum.DominantAxis.Height
			aspect.Parent = icon

			btn.Typed.Position = UDim2.new(0, iconOffset, 0, 0)
		elseif suggestion.Color then
			iconOffset = 25
			local icon = Instance.new("Frame")
			icon.BackgroundColor3 = suggestion.Color
			icon.BorderSizePixel = 0
			icon.Size = UDim2.new(1, 0, 1, 0)
			icon.Position = UDim2.new(0, -10, 0.5, 0)
			icon.AnchorPoint = Vector2.new(0, 0.5)
			icon.Parent = btn

			local aspect = Instance.new("UIAspectRatioConstraint")
			aspect.AspectRatio = 1
			aspect.DominantAxis = Enum.DominantAxis.Height
			aspect.Parent = icon

			btn.Typed.Position = UDim2.new(0, iconOffset, 0, 0)
		else
			btn.Typed.Position = UDim2.new(0, 0, 0, 0)
		end

		local textWidth = TextService:GetTextSize(displayString, 14, Enum.Font.Code, Vector2.new(1000, 20)).X
		if textWidth + iconOffset > maxTextWidth then maxTextWidth = textWidth + iconOffset end

		if suggestion.Description and suggestion.Description ~= "" then
			btn.Suggest.Text = "- " .. suggestion.Description
			btn.Suggest.TextColor3 = Color3.fromRGB(150, 150, 150)
			local descWidth = TextService:GetTextSize(btn.Suggest.Text, 14, Enum.Font.Code, Vector2.new(1000, 20)).X
			if descWidth > maxDescWidth then maxDescWidth = descWidth end
		else
			btn.Suggest.Text = ""
		end
		btn.Parent = autocompleteDropdown
		table.insert(suggestionButtons, btn)

		btn.MouseEnter:Connect(function()
			highlightSuggestion(i)
		end)
		btn.MouseButton1Down:Connect(function()
			applySuggestion(suggestion.Text)
			task.defer(function()
				inputBar:CaptureFocus()
			end)
		end)
	end

	for _, btn in ipairs(suggestionButtons) do
		btn.Suggest.Position = UDim2.new(0, maxTextWidth + 15, 0, 0)
	end

	local hasTitle = cmdInfo ~= nil
	local hasDesc = cmdInfo and cmdInfo.Description and cmdInfo.Description ~= ""

	local visibleItems = 0
	local yHeight = 10
	if hasTitle then
		yHeight += 40
		visibleItems += 1
	end
	if hasDesc then
		yHeight += 20
		visibleItems += 1
	end
	if #suggestions > 0 then
		local visibleSugs = math.min(5, #suggestions)
		yHeight += (visibleSugs * 30)
		visibleItems += visibleSugs
	end
	if visibleItems > 1 then
		yHeight += (visibleItems - 1) * 2
	end

	highlightSuggestion(1)

	local requiredWidth = math.max(maxTextWidth + maxDescWidth + 40, titleWidth)
	autocompleteDropdown.Size = UDim2.new(0, math.max(300, requiredWidth), 0, yHeight)
end

local function getDesiredHeight()
	if not mainFrame then return 0 end
	local layout = mainFrame:FindFirstChildOfClass("UIListLayout")
	local contentH = layout and layout.AbsoluteContentSize.Y or 0
	local maxH = math.min(workspace.CurrentCamera.ViewportSize.Y * 0.25, 250)
	return math.min(contentH + 10, maxH)
end

local function toggleConsole()
	isVisible = not isVisible

	local targetH = isVisible and getDesiredHeight() or 0
	local targetSize = UDim2.new(0.95, 0, 0, targetH)
	local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	local tween = TweenService:Create(mainFrame, tweenInfo, { Size = targetSize })

	if isVisible then
		mainFrame.Visible = true
		tween:Play()
		task.defer(function()
			inputBar:CaptureFocus()
			updateSuggestions()
			mainFrame.CanvasPosition = Vector2.new(0, 99999999)
		end)
	else
		closeSuggestions()
		tween:Play()
		tween.Completed:Connect(function()
			if not isVisible then
				mainFrame.Visible = false
			end
		end)
	end
end

function Display.Init(ts)
	terminalService = ts
	if not RunService:IsClient() then return end

	createUI()

	printToConsole("Terminal Service v1.0.0", Color3.fromRGB(150, 150, 150))
	printToConsole("Type 'help' for a list of available commands.", Color3.fromRGB(150, 150, 150))
	printToConsole("", Color3.fromRGB(255, 255, 255))

	local inputCounters = {}
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.KeyCode == Enum.KeyCode.RightShift then
			toggleConsole()
		elseif isVisible and UserInputService:GetFocusedTextBox() == inputBar then
			if input.KeyCode == Enum.KeyCode.Up or input.KeyCode == Enum.KeyCode.Down then
				local isUp = (input.KeyCode == Enum.KeyCode.Up)

				local function action()
					local hasSuggestions = autocompleteDropdown.Visible and #activeSuggestions > 0
					local ctrlPressed = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)

					if hasSuggestions and not ctrlPressed then
						local newIndex = isUp and (selectedSuggestionIndex - 1) or (selectedSuggestionIndex + 1)
						if newIndex < 1 then newIndex = #activeSuggestions end
						if newIndex > #activeSuggestions then newIndex = 1 end
						highlightSuggestion(newIndex)
					else
						if isUp then
							if historyIndex > 1 then
								historyIndex -= 1
								inputBar.Text = commandHistory[historyIndex]
								task.defer(function() inputBar.CursorPosition = #inputBar.Text + 1 end)
							end
						else
							if historyIndex < #commandHistory then
								historyIndex += 1
								inputBar.Text = commandHistory[historyIndex]
								task.defer(function() inputBar.CursorPosition = #inputBar.Text + 1 end)
							elseif historyIndex == #commandHistory then
								historyIndex = #commandHistory + 1
								inputBar.Text = ""
							end
						end
					end
				end

				action()

				local counter = (inputCounters[input.KeyCode] or 0) + 1
				inputCounters[input.KeyCode] = counter

				task.spawn(function()
					task.wait(0.4)
					while inputCounters[input.KeyCode] == counter and UserInputService:IsKeyDown(input.KeyCode) do
						if not isVisible or UserInputService:GetFocusedTextBox() ~= inputBar then break end
						action()
						task.wait(0.05)
					end
				end)
			end
		end
	end)

	inputBar.Focused:Connect(function()
		updateSuggestions()
	end)

	inputBar:GetPropertyChangedSignal("Text"):Connect(function()
		local text = inputBar.Text
		local cleaned = string.gsub(text, "\t", "")
		if cleaned ~= text then
			inputBar.Text = cleaned
			inputBar.CursorPosition = #cleaned + 1
		end
		updateSuggestions()
	end)

	UserInputService.TextBoxFocused:Connect(function(focusedBox)
		if focusedBox == inputBar then
			task.spawn(function()
				while UserInputService:GetFocusedTextBox() == inputBar do
					if UserInputService:IsKeyDown(Enum.KeyCode.Tab) then
						if autocompleteDropdown.Visible and #activeSuggestions > 0 then
							applySuggestion(activeSuggestions[selectedSuggestionIndex].Text)
						end
						task.wait(0.15)
					end
					task.wait()
				end
			end)
		end
	end)

	local isInteracting = false
	autocompleteDropdown.MouseEnter:Connect(function() isInteracting = true end)
	autocompleteDropdown.MouseLeave:Connect(function() isInteracting = false end)

	inputBar.FocusLost:Connect(function(enterPressed)
		if not enterPressed then
			task.delay(0.15, function()
				if UserInputService:GetFocusedTextBox() ~= inputBar and not isInteracting then
					closeSuggestions()
				end
			end)
			return
		end

		closeSuggestions()

		local line = inputBar.Text
		inputBar.Text = ""

		if line == "" then
			task.defer(function() inputBar:CaptureFocus() end)
			return
		end

		table.insert(commandHistory, line)
		historyIndex = #commandHistory + 1

		printToConsole(line, Color3.fromRGB(200, 200, 200), getPrompt(true))

		task.spawn(function()
			local code, stdout, stderr = terminalService:Execute(line)

			if stderr ~= "" then
				printToConsole(stderr, Color3.fromRGB(255, 100, 100))
			elseif stdout ~= "" then
				printToConsole(stdout, Color3.fromRGB(255, 255, 255))
			end

			task.defer(function()
				if isVisible then
					inputBar:CaptureFocus()
				end
			end)
		end)
	end)

	RunService.RenderStepped:Connect(function()
		if isVisible and expectedDropdownVisible then
			local isAtBottom = mainFrame.CanvasPosition.Y >= (mainFrame.AbsoluteCanvasSize.Y - mainFrame.AbsoluteWindowSize.Y - 25)
			if isAtBottom then
				autocompleteDropdown.Visible = true
				local x = inputBar.AbsolutePosition.X
				local y = inputBar.AbsolutePosition.Y + inputBar.AbsoluteSize.Y + 5
				autocompleteDropdown.Position = UDim2.fromOffset(x, y)
			else
				autocompleteDropdown.Visible = false
			end
		elseif not expectedDropdownVisible then
			autocompleteDropdown.Visible = false
		end
	end)

	local Network = ts and ts.Network
	if Network then
		Network:OnEvent(function(header, action, ...)
			if action == "RedirectPrint" then
				local message = ...
				printToConsole(message)
			elseif action == "TerminalPrint" then
				local data = ...
				local msg, kind = data.Message, data.Kind or "Normal"
				local k = string.lower(kind or "Normal")
				local color
				if k == "error" then color = Color3.fromRGB(255, 100, 100)
				elseif k == "success" then color = Color3.fromRGB(100, 230, 130)
				elseif k == "info" then color = Color3.fromRGB(120, 200, 255)
				elseif k == "message" then color = Color3.fromRGB(255, 220, 100)
				elseif k == "hint" then color = Color3.fromRGB(180, 180, 220)
				elseif k == "pm" or k == "whisper" then color = Color3.fromRGB(220, 180, 255)
				else color = Color3.fromRGB(255, 255, 255) end
				printToConsole(`[{kind}] {msg}`, color)
			elseif action == "SystemChat" then
				local message = ...
				printToConsole(`<System> {message}`, Color3.fromRGB(180, 220, 255))
			elseif action == "Noclip" or action == "Invisible" then
			end
		end)
	end
end

return Display
