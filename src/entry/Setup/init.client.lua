
local MainView = require(game.ReplicatedStorage.MainView)
local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)
local DebugFlags = require(game.ReplicatedStorage.DebugFlags)

task.wait()
local s = game:GetService('StarterGui')
s:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)

local Player = game.Players.LocalPlayer
local PlayerGui = Player:WaitForChild('PlayerGui')

-- Create a GUI for our stuff. Deliberately NOT IgnoreGuiInset: gui-space then
-- matches InputObject.Position coordinates everywhere (drag ghosts, sliders),
-- and the play area behind the top bar is the 3D view anyway.
local ScreenGui = Instance.new('ScreenGui', PlayerGui)
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

if not LocalPlayerData:Load() then

end

local TitleScreen = PlayerGui:WaitForChild('TitleScreen')

-- Debug checkpoint picker on the title screen: jump straight to the first
-- entry of a security level. Must resolve BEFORE MainView is constructed
-- (the netmap reads progression at build time), so with the picker enabled
-- the MainView is built after the title-screen click instead of during it.
local mCheckpointLevel = 1
if DebugFlags:ShowDebugCheckpoints() then
	local picker = Instance.new('Frame')
	picker.Name = 'DebugCheckpoints'
	picker.AnchorPoint = Vector2.new(0.5, 1)
	picker.Position = UDim2.new(0.5, 0, 1, -12)
	picker.Size = UDim2.new(0, 640, 0, 64)
	picker.BackgroundColor3 = Color3.fromRGB(192, 192, 192)
	picker.BorderSizePixel = 1
	-- Above the title screen's full-screen ClickOverlay in any ZIndexBehavior
	picker.ZIndex = 10

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
	picker.Parent = TitleScreen
end

local function waitForPreload()
	if not TitleScreen.PreloadCompleted.Value then
		TitleScreen.PreloadCompleted.Changed:wait()
	end
end

local mv
if DebugFlags:ShowDebugCheckpoints() then
	-- The auto-dismissing title screen is the picker's only window, so with
	-- the picker up, hold the title screen open until a click
	waitForPreload()
	TitleScreen.Content.TitleImage.LoadingText.Text = "> DEBUG: pick a checkpoint, then click to start <"
	TitleScreen.Content.ClickOverlay.MouseButton1Click:Wait()
	if mCheckpointLevel > 1 then
		LocalPlayerData:ApplyDebugCheckpoint(mCheckpointLevel)
	end
	mv = MainView.new()
else
	-- Normal flow: build the main view during the loading screen and go
	-- straight in once the preloads finish
	mv = MainView.new()
	waitForPreload()
end

-- Preload completed, show the main view
mv:GetGui().Parent = ScreenGui

-- Remove the loading screen now that we're ready
TitleScreen:Destroy()

game:GetService('UserInputService').ModalEnabled = true
