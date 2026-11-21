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
	Client-side terminal UI.

	Builds the compact Rovue console from the module's instance templates, renders
	output, drives autocomplete and toggles the terminal with RightShift.
]=]

local __ = _G()
local Display = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer.PlayerGui

local TOGGLE_KEYCODE = Enum.KeyCode.RightShift

local terminalGui
local mainFrame
local inputBar
local autocompleteDropdown

-- The UI lives as real instances right under this module (src/Display).
-- Nothing below builds a GuiObject from code: the screen is cloned once, and
-- every repeated row is a template clone.
local uiTemplates = script.Templates
local terminalTemplate = script.Terminal

local lineTemplate = uiTemplates.Line
local promptLineTemplate = uiTemplates.PromptLine
local suggestTemplate = uiTemplates.Suggestion
local titleTemplate = uiTemplates.Signature
local descriptionTemplate = uiTemplates.Description

-- The client runtime detaches every descendant before loading, so a plain
-- Clone() would return an empty instance. Rebuild one real prototype from the
-- Node tree, then native Clone() keeps working.
--[=[
	Rebuilds a cloned instance tree whose descendants were detached.

	@param node The syntax tree node to evaluate.

	@return The rebuilt instance tree.
]=]
local function repairTree(node)
	local clone = node:Clone()
	for _, child in node:GetChildren() do
		repairTree(child).Parent = clone
	end
	return clone
end

local terminalPrototype = repairTree(terminalTemplate)
local linePrototype = repairTree(lineTemplate)
local promptLinePrototype = repairTree(promptLineTemplate)
local suggestPrototype = repairTree(suggestTemplate)
local titlePrototype = repairTree(titleTemplate)
local descriptionPrototype = repairTree(descriptionTemplate)

local entryFrame

local isVisible = false
local terminalService
local commandHistory = {}
local historyIndex = 1
local activeSuggestions = {}
local selectedSuggestionIndex = 1
local suggestionButtons = {}
local expectedDropdownVisible = false
local currentActiveArgText = ""
local lastSuggestionText = ""

--[=[
	Formats the shell prompt, optionally as rich text.

	@param isHtml Whether the prompt uses rich text.

	@return The formatted prompt.
]=]
local function getPrompt(isHtml: boolean)
	local playerName = localPlayer.Name
	if isHtml then
		return `<b><font color="#85e89d">{playerName}@roblox</font></b>:<font color="#79c0ff">~</font>$ `
	else
		return `{playerName}@roblox:~$ `
	end
end

--[=[
	Computes the console height for its current content.

	@return The console height in pixels.
]=]
local function getDesiredHeight()
	if not mainFrame then
		return 0
	end
	local layout = mainFrame:FindFirstChildOfClass("UIListLayout")
	local contentH = layout and layout.AbsoluteContentSize.Y or 0
	local maxH = math.min(workspace.CurrentCamera.ViewportSize.Y * 0.25, 250)
	return math.min(contentH + 10, maxH)
end

--[=[
	Clones the terminal templates into PlayerGui.
]=]
local function createUI()
	terminalGui = terminalPrototype:Clone()
	terminalGui.Parent = playerGui

	mainFrame = terminalGui.Frame
	entryFrame = mainFrame.Entry
	autocompleteDropdown = terminalGui.Autocomplete
	inputBar = entryFrame.Field

	-- The prompt carries the player's name, so it is the one label set at runtime.
	entryFrame.Prompt.Text = getPrompt(true)

	local contentLayout = mainFrame:FindFirstChildOfClass("UIListLayout")
	contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		if isVisible then
			mainFrame.Size = UDim2.new(0.95, 0, 0, getDesiredHeight())
		end
	end)
end

-- Oldest lines go past this: output redirected by others could otherwise grow
-- the console for ever.
local MAX_LINES = 500
local consoleLines: { Instance } = {}

--[=[
	Appends one output line, handling clear sequences and the line cap.

	@param text The text to inspect.
	@param color The colour to apply.
	@param promptHtml Whether the prompt row uses rich text.
]=]
local function printToConsole(text: string, color: Color3?, promptHtml: string?)
	local clearChunks = string.split(text, "\27[2J")
	if #clearChunks > 1 then
		for _, child in mainFrame:GetChildren() do
			if child.Name == "Line" then
				child:Destroy()
			end
		end
		table.clear(consoleLines)
		text = clearChunks[#clearChunks]
		if string.sub(text, 1, 1) == "\n" then
			text = string.sub(text, 2)
		end
		if text == "" then
			return
		end
	end

	text = string.gsub(text, "\t", "    ")

	-- Both rows are templates: the prompt one only adds the echoed command's
	-- prompt.
	local template = if promptHtml then promptLinePrototype else linePrototype
	local lineFrame = template:Clone()
	lineFrame.Name = "Line" -- the clear loop and the 500-line cap find rows by this name

	if promptHtml then
		lineFrame.Prompt.Text = promptHtml
	end

	local content = lineFrame.Content
	content.Text = text
	content.TextColor3 = color or Color3.fromRGB(255, 255, 255)

	lineFrame.Parent = mainFrame

	table.insert(consoleLines, lineFrame)
	if #consoleLines > MAX_LINES then
		table.remove(consoleLines, 1):Destroy()
	end

	task.defer(function()
		mainFrame.CanvasPosition = Vector2.new(0, mainFrame.AbsoluteCanvasSize.Y)
	end)
end

--[=[
	Hides and clears the autocomplete dropdown.
]=]
local function closeSuggestions()
	expectedDropdownVisible = false
	autocompleteDropdown.Visible = false
	for _, child in autocompleteDropdown:GetChildren() do
		if
			not child:IsA("UIListLayout")
			and not child:IsA("UIPadding")
			and not child:IsA("UIStroke")
		then
			child:Destroy()
		end
	end
	table.clear(suggestionButtons)
	activeSuggestions = {}
end

--[=[
	Replaces the active argument with a suggestion.

	@param suggestion The suggestion being handled.
]=]
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

--[=[
	Highlights one suggestion and scrolls it into view.

	@param index The position to start at.
]=]
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
			autocompleteDropdown.CanvasPosition =
				Vector2.new(0, autocompleteDropdown.CanvasPosition.Y - (viewTop - btnTop))
		elseif btnBottom > viewBottom then
			autocompleteDropdown.CanvasPosition =
				Vector2.new(0, autocompleteDropdown.CanvasPosition.Y + (btnBottom - viewBottom))
		end
	end
end

--[=[
	Builds the command signature header in the dropdown.

	@param cmdInfo The command metadata to send.
	@param activeIndex The highlighted suggestion index.
]=]
local function buildSignatureUI(cmdInfo, activeIndex)
	local title = titlePrototype:Clone()
	title.Visible = true
	title.Parent = autocompleteDropdown

	local templateField = title:FindFirstChild("Field")
	if templateField then
		templateField.Parent = nil

		local nameField = templateField:Clone()
		nameField.Text = cmdInfo.Name
		nameField.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameField.Parent = title

		for i, argument in ipairs(cmdInfo.Args) do
			local f = templateField:Clone()
			local argName = argument.Name or argument.name or "unknown"
			local argType = argument.Type or argument.type or "any"
			if type(argType) ~= "string" then
				argType = "any"
			end
			argType = ": " .. argType

			local r, g, b
			if i == activeIndex then
				r, g, b = 255, 255, 255
			else
				r, g, b = 150, 150, 150
			end

			f.TextSize = 17
			f.Text = string.format(
				[[<font color="rgb(%d,%d,%d)">%s<font size="13" face="SourceSans">%s</font></font>]],
				r,
				g,
				b,
				argName,
				argType
			)
			f.Parent = title
		end
	end

	if cmdInfo.Description and cmdInfo.Description ~= "" then
		local description = descriptionPrototype:Clone()
		description.Label.Text = cmdInfo.Description
		description.Visible = true
		description.Parent = autocompleteDropdown
	end
end

local isLiveUpdating = false

--[=[
	Updates the input while a custom picker changes.

	@param suggestion The suggestion being handled.
]=]
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

--[=[
	Rebuilds the autocomplete dropdown for the current input.

	@param forceRebuild Whether to rebuild even when cached.
]=]
local function updateSuggestions(forceRebuild)
	if not terminalService then
		return
	end
	if isLiveUpdating then
		return
	end

	local currentText = inputBar.Text
	currentText = string.gsub(currentText, "\t", "")

	if not forceRebuild and autocompleteDropdown.Visible and lastSuggestionText == currentText then
		return
	end
	lastSuggestionText = currentText

	local data = terminalService:GetAutocompleteSuggestions(currentText)
	if type(data) ~= "table" then
		-- the bridge answers nil when it could not serialize the reply: do not
		-- kill the client UI
		closeSuggestions()
		return
	end
	local suggestions = data.Suggestions or {}
	local cmdInfo = data.CommandInfo
	local activeIndex = data.ActiveArgIndex or 1
	currentActiveArgText = data.CurrentArgText or ""

	for _, child in autocompleteDropdown:GetChildren() do
		if
			not child:IsA("UIListLayout")
			and not child:IsA("UIPadding")
			and not child:IsA("UIStroke")
		then
			child:Destroy()
		end
	end
	table.clear(suggestionButtons)

	local titleWidth = 0
	if cmdInfo then
		buildSignatureUI(cmdInfo, activeIndex)

		local nameW = TextService:GetTextSize(
			cmdInfo.Name,
			20,
			Enum.Font.SourceSansBold,
			Vector2.new(1000, 20)
		).X
		titleWidth = 10 + nameW
		for _, argument in ipairs(cmdInfo.Args) do
			local argName = argument.Name or argument.name or "unknown"
			local argType = argument.Type or argument.type or "any"
			if type(argType) ~= "string" then
				argType = "any"
			end
			argType = ": " .. argType
			local nW = TextService:GetTextSize(
				argName,
				17,
				Enum.Font.SourceSansBold,
				Vector2.new(1000, 20)
			).X
			local tW =
				TextService:GetTextSize(argType, 13, Enum.Font.SourceSans, Vector2.new(1000, 20)).X
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
							task.defer(function()
								inputBar:CaptureFocus()
							end)
						end,
						function() -- keepFocus
							task.defer(function()
								inputBar:CaptureFocus()
							end)
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

						autocompleteDropdown.Size =
							UDim2.new(0, math.max(300, titleWidth), 0, uiHeight)
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
		local btn = suggestPrototype:Clone()
		btn.Text = ""
		local displayString = suggestion.DisplayText or suggestion.Text
		btn.Typed.Text = displayString

		local iconOffset = 0
		local icon = btn.Icon
		local iconImage = icon.IconImage

		if suggestion.Icon then
			iconOffset = 25
			icon.Visible = true
			icon.BackgroundTransparency = 1
			iconImage.Image = suggestion.Icon
			iconImage.Visible = true
			btn.Typed.Position = UDim2.new(0, iconOffset, 0, 0)
		elseif suggestion.Color then
			iconOffset = 25
			icon.Visible = true
			icon.BackgroundColor3 = suggestion.Color
			icon.BackgroundTransparency = 0
			iconImage.Visible = false
			btn.Typed.Position = UDim2.new(0, iconOffset, 0, 0)
		else
			icon.Visible = false
			btn.Typed.Position = UDim2.new(0, 0, 0, 0)
		end

		local textWidth =
			TextService:GetTextSize(displayString, 14, Enum.Font.Code, Vector2.new(1000, 20)).X
		if textWidth + iconOffset > maxTextWidth then
			maxTextWidth = textWidth + iconOffset
		end

		if suggestion.Description and suggestion.Description ~= "" then
			btn.Suggest.Text = "- " .. suggestion.Description
			btn.Suggest.TextColor3 = Color3.fromRGB(150, 150, 150)
			local descWidth = TextService:GetTextSize(
				btn.Suggest.Text,
				14,
				Enum.Font.Code,
				Vector2.new(1000, 20)
			).X
			if descWidth > maxDescWidth then
				maxDescWidth = descWidth
			end
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

--[=[
	Opens or closes the terminal with a tween.
]=]
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
		-- otherwise the hidden input keeps focus and every key typed next goes
		-- into the closed terminal
		inputBar:ReleaseFocus()

		closeSuggestions()
		tween:Play()
		tween.Completed:Connect(function()
			if not isVisible then
				mainFrame.Visible = false
			end
		end)
	end
end

--[=[
	Mounts the client UI and wires input, history and network events.

	@param ts The terminal service.
]=]
function Display.Mount(ts)
	terminalService = ts
	if not RunService:IsClient() then
		return
	end

	createUI()

	printToConsole("Terminal Service v1.0.0", Color3.fromRGB(150, 150, 150))
	printToConsole("Type 'help' for a list of available commands.", Color3.fromRGB(150, 150, 150))
	printToConsole("", Color3.fromRGB(255, 255, 255))

	local inputCounters = {}
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.KeyCode == TOGGLE_KEYCODE then
			toggleConsole()
		elseif isVisible and UserInputService:GetFocusedTextBox() == inputBar then
			if input.KeyCode == Enum.KeyCode.Up or input.KeyCode == Enum.KeyCode.Down then
				local isUp = (input.KeyCode == Enum.KeyCode.Up)

				--[=[
					Moves through suggestions or history for an arrow key press.
				]=]
				local function action()
					local hasSuggestions = autocompleteDropdown.Visible and #activeSuggestions > 0
					local ctrlPressed = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
						or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)

					if hasSuggestions and not ctrlPressed then
						local newIndex = isUp and (selectedSuggestionIndex - 1)
							or (selectedSuggestionIndex + 1)
						if newIndex < 1 then
							newIndex = #activeSuggestions
						end
						if newIndex > #activeSuggestions then
							newIndex = 1
						end
						highlightSuggestion(newIndex)
					else
						if isUp then
							if historyIndex > 1 then
								historyIndex -= 1
								inputBar.Text = commandHistory[historyIndex]
								task.defer(function()
									inputBar.CursorPosition = #inputBar.Text + 1
								end)
							end
						else
							if historyIndex < #commandHistory then
								historyIndex += 1
								inputBar.Text = commandHistory[historyIndex]
								task.defer(function()
									inputBar.CursorPosition = #inputBar.Text + 1
								end)
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
					while
						inputCounters[input.KeyCode] == counter
						and UserInputService:IsKeyDown(input.KeyCode)
					do
						if not isVisible or UserInputService:GetFocusedTextBox() ~= inputBar then
							break
						end
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
	autocompleteDropdown.MouseEnter:Connect(function()
		isInteracting = true
	end)
	autocompleteDropdown.MouseLeave:Connect(function()
		isInteracting = false
	end)

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
			-- isVisible, as below: an empty line sent just before closing took
			-- focus back in a hidden terminal
			task.defer(function()
				if isVisible then
					inputBar:CaptureFocus()
				end
			end)
			return
		end

		table.insert(commandHistory, line)
		historyIndex = #commandHistory + 1

		printToConsole(line, Color3.fromRGB(200, 200, 200), getPrompt(true))

		task.spawn(function()
			local code, stdout, stderr = terminalService:Execute(line)

			if stderr ~= "" then
				printToConsole(`error: {stderr}`, Color3.fromRGB(255, 100, 100))
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
			local isAtBottom = mainFrame.CanvasPosition.Y
				>= (mainFrame.AbsoluteCanvasSize.Y - mainFrame.AbsoluteWindowSize.Y - 25)
			if isAtBottom then
				if not autocompleteDropdown.Visible then
					autocompleteDropdown.Visible = true
				end
				local x = inputBar.AbsolutePosition.X
				local y = inputBar.AbsolutePosition.Y + inputBar.AbsoluteSize.Y + 5
				autocompleteDropdown.Position = UDim2.fromOffset(x, y)
			elseif autocompleteDropdown.Visible then
				autocompleteDropdown.Visible = false
			end
		elseif not expectedDropdownVisible and autocompleteDropdown.Visible then
			-- written only when it changes: this ran on every frame of every
			-- client, terminal closed
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
				if k == "error" then
					color = Color3.fromRGB(255, 100, 100)
				elseif k == "success" then
					color = Color3.fromRGB(100, 230, 130)
				elseif k == "info" then
					color = Color3.fromRGB(120, 200, 255)
				elseif k == "message" then
					color = Color3.fromRGB(255, 220, 100)
				elseif k == "hint" then
					color = Color3.fromRGB(180, 180, 220)
				elseif k == "pm" or k == "whisper" then
					color = Color3.fromRGB(220, 180, 255)
				else
					color = Color3.fromRGB(255, 255, 255)
				end
				printToConsole(`[{kind}] {msg}`, color)
			elseif action == "SystemChat" then
				local message = ...
				printToConsole(`<System> {message}`, Color3.fromRGB(180, 220, 255))
			elseif action == "Noclip" or action == "Invisible" then
			end
		end)
	end
end

--[=[
    @client
]=]
return __(Display)
