
local MainView = require(game.ReplicatedStorage.MainView)
local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)
local DebugFlags = require(game.ReplicatedStorage.DebugFlags)

task.wait()
local s = game:GetService('StarterGui')
s:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
-- ...except chat: players should be able to talk to each other
s:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)

local Player = game.Players.LocalPlayer
local PlayerGui = Player:WaitForChild('PlayerGui')

-- Create a GUI for our stuff. Deliberately NOT IgnoreGuiInset: gui-space then
-- matches InputObject.Position coordinates everywhere (drag ghosts, sliders),
-- and the play area behind the top bar is the 3D view anyway.
local ScreenGui = Instance.new('ScreenGui', PlayerGui)
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

if not LocalPlayerData:Load() then

end

-- Debug checkpoint picker: jump straight to the first entry of a security
-- level. Must resolve BEFORE MainView is constructed (the netmap reads
-- progression at build time), so debug builds pause on a small overlay —
-- the only thing that ever holds up entry; normal players go straight in.
local mCheckpointLevel = 1
if DebugFlags:ShowDebugCheckpoints() then
	local overlay = Instance.new('ScreenGui')
	overlay.Name = 'DebugCheckpointPicker'
	overlay.IgnoreGuiInset = true
	overlay.DisplayOrder = 100
	overlay.Parent = PlayerGui

	local dim = Instance.new('Frame')
	dim.Size = UDim2.new(1, 0, 1, 0)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.4
	dim.BorderSizePixel = 0
	dim.Parent = overlay

	local picker = Instance.new('Frame')
	picker.Name = 'DebugCheckpoints'
	picker.AnchorPoint = Vector2.new(0.5, 0.5)
	picker.Position = UDim2.new(0.5, 0, 0.5, 0)
	picker.Size = UDim2.new(0, 640, 0, 102)
	picker.BackgroundColor3 = Color3.fromRGB(192, 192, 192)
	picker.BorderSizePixel = 1
	picker.ZIndex = 10
	picker.Parent = overlay

	local title = Instance.new('TextLabel')
	title.Position = UDim2.new(0, 0, 0, 2)
	title.Size = UDim2.new(1, 0, 0, 16)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.Code
	title.TextSize = 14
	title.TextColor3 = Color3.new(0, 0, 0)
	title.Text = "DEBUG: start at checkpoint"
	title.ZIndex = 11
	title.Parent = picker

	local kCheckpoints = {
		{ Level = 1, Label = "Fresh" },
		{ Level = 2, Label = "Security 2" },
		{ Level = 3, Label = "Security 3" },
		{ Level = 4, Label = "Security 4" },
		{ Level = 5, Label = "Security 5" },
	}
	local buttons = {}
	local function refresh()
		for _, entry in pairs(buttons) do
			local selected = entry.Level == mCheckpointLevel
			entry.Button.BackgroundColor3 = if selected
				then Color3.new(0, 0, 0.5)
				else Color3.new(1, 1, 1)
			entry.Button.TextColor3 = if selected
				then Color3.new(1, 1, 1)
				else Color3.new(0, 0, 0)
		end
	end
	for i, checkpoint in pairs(kCheckpoints) do
		local button = Instance.new('TextButton')
		button.Position = UDim2.new(0, 8 + (i - 1) * 126, 0, 22)
		button.Size = UDim2.new(0, 118, 0, 32)
		button.Font = Enum.Font.Code
		button.TextSize = 15
		button.Text = checkpoint.Label
		button.BorderSizePixel = 1
		button.ZIndex = 11
		button.MouseButton1Click:Connect(function()
			mCheckpointLevel = checkpoint.Level
			refresh()
		end)
		button.Parent = picker
		table.insert(buttons, { Level = checkpoint.Level, Button = button })
	end
	refresh()

	local startButton = Instance.new('TextButton')
	startButton.AnchorPoint = Vector2.new(0.5, 0)
	startButton.Position = UDim2.new(0.5, 0, 0, 62)
	startButton.Size = UDim2.new(0, 160, 0, 32)
	startButton.BackgroundColor3 = Color3.new(0.701961, 0, 0)
	startButton.Font = Enum.Font.Code
	startButton.TextSize = 16
	startButton.TextColor3 = Color3.new(1, 1, 1)
	startButton.Text = "START"
	startButton.BorderSizePixel = 1
	startButton.ZIndex = 11
	startButton.Parent = picker

	startButton.MouseButton1Click:Wait()
	overlay:Destroy()
	if mCheckpointLevel > 1 then
		LocalPlayerData:ApplyDebugCheckpoint(mCheckpointLevel)
	end
end

-- Straight in: no loading screen (BOOTSTRAP warms assets in the background)
local mv = MainView.new()
mv:GetGui().Parent = ScreenGui

game:GetService('UserInputService').ModalEnabled = true
