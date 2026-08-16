-- Nightfall Debug Flags panel: toggles the Workspace attributes that
-- src/shared/DebugFlags.lua reads. Attributes persist with the place file
-- (and the game's failsafe ignores them outside Studio, so leaving one on
-- can't affect the published game).

local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- Keep in sync with kProduction in src/shared/DebugFlags.lua (the Default
-- here is only used for DISPLAY when no attribute is set)
local kFlags = {
	{ Name = "UseMockData", Label = "Mock datastores", Default = false },
	{ Name = "PlayTutorial", Label = "Play tutorial", Default = true },
	{ Name = "HasBeatenAllNodes", Label = "All nodes beaten", Default = false },
	{ Name = "ShowDebugUI", Label = "Debug UI (checkpoints, win)", Default = false },
	{ Name = "EnableDialogueVoices", Label = "Dialogue TTS voices", Default = false },
	{ Name = "LotsOfCredits", Label = "Lots of credits", Default = false },
}

local kRowHeight = 26

local toolbar = plugin:CreateToolbar("Nightfall")
local button = toolbar:CreateButton("Debug Flags", "Toggle Nightfall debug flags", "rbxassetid://1507949215")

local widget = plugin:CreateDockWidgetPluginGui("NightfallDebugFlags", DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,
	false, -- initially enabled
	false, -- don't override the saved enabled state
	240, 40 + #kFlags * kRowHeight,
	200, 120
))
widget.Title = "Nightfall Debug Flags"

local function attributeName(flag)
	return "Debug" .. flag.Name
end

local function effectiveValue(flag)
	local value = workspace:GetAttribute(attributeName(flag))
	if value == nil then
		return flag.Default
	end
	return value == true
end

local background = Instance.new("Frame")
background.Size = UDim2.new(1, 0, 1, 0)
background.BackgroundColor3 = Color3.fromRGB(46, 46, 46)
background.BorderSizePixel = 0
background.Parent = widget

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 2)
layout.Parent = background

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 6)
padding.PaddingLeft = UDim.new(0, 6)
padding.PaddingRight = UDim.new(0, 6)
padding.Parent = background

local rows = {}
local function refresh()
	for _, row in pairs(rows) do
		local on = effectiveValue(row.Flag)
		local isDefault = workspace:GetAttribute(attributeName(row.Flag)) == nil
		row.Check.Text = on and "☑" or "☐"
		row.Check.TextColor3 = on and Color3.fromRGB(120, 220, 120) or Color3.fromRGB(160, 160, 160)
		row.Label.Text = row.Flag.Label .. (isDefault and "" or " *")
		row.Label.TextColor3 = on and Color3.fromRGB(235, 235, 235) or Color3.fromRGB(170, 170, 170)
	end
end

for i, flag in pairs(kFlags) do
	local rowButton = Instance.new("TextButton")
	rowButton.LayoutOrder = i
	rowButton.Size = UDim2.new(1, 0, 0, kRowHeight - 2)
	rowButton.BackgroundColor3 = Color3.fromRGB(56, 56, 56)
	rowButton.BorderSizePixel = 0
	rowButton.Text = ""
	rowButton.AutoButtonColor = true
	rowButton.Parent = background

	local check = Instance.new("TextLabel")
	check.Size = UDim2.new(0, 24, 1, 0)
	check.BackgroundTransparency = 1
	check.Font = Enum.Font.SourceSansBold
	check.TextSize = 18
	check.Parent = rowButton

	local label = Instance.new("TextLabel")
	label.Position = UDim2.new(0, 26, 0, 0)
	label.Size = UDim2.new(1, -30, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.SourceSans
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = rowButton

	rowButton.MouseButton1Click:Connect(function()
		workspace:SetAttribute(attributeName(flag), not effectiveValue(flag))
		ChangeHistoryService:SetWaypoint("Toggle " .. flag.Name)
		refresh()
	end)

	table.insert(rows, { Flag = flag, Check = check, Label = label })
end

-- A footnote: '*' rows have an explicit attribute; the rest show defaults
local footnote = Instance.new("TextLabel")
footnote.LayoutOrder = #kFlags + 1
footnote.Size = UDim2.new(1, 0, 0, 18)
footnote.BackgroundTransparency = 1
footnote.Font = Enum.Font.SourceSans
footnote.TextSize = 13
footnote.TextColor3 = Color3.fromRGB(140, 140, 140)
footnote.TextXAlignment = Enum.TextXAlignment.Left
footnote.Text = "* = set in place; others show defaults"
footnote.Parent = background

-- Follow attribute changes made elsewhere (undo, another session, scripts)
workspace.AttributeChanged:Connect(refresh)
refresh()

button.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)
widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	button:SetActive(widget.Enabled)
end)
button:SetActive(widget.Enabled)
