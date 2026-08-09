
local MainView = require(game.ReplicatedStorage.MainView)
local LocalPlayerData = require(game.ReplicatedStorage.LocalPlayerData)

task.wait()
local s = game:GetService('StarterGui')
s:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)

local Player = game.Players.LocalPlayer
local PlayerGui = Player:WaitForChild('PlayerGui')

-- Create a GUI for our stuff
local ScreenGui = Instance.new('ScreenGui', PlayerGui)
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true

-- Create the main game view
if not LocalPlayerData:Load() then
	
end
local mv = MainView.new()

-- Wait for the preload to complete
local TitleScreen = PlayerGui:WaitForChild('TitleScreen')
if not TitleScreen.PreloadCompleted.Value then
	TitleScreen.PreloadCompleted.Changed:wait()
end

-- Init google anylitics


-- Preload completed, show the main view
mv:GetGui().Parent = ScreenGui

-- Remove the loading screen now that we're ready
TitleScreen:Destroy()

game:GetService('UserInputService').ModalEnabled = true

workspace.Baseplate:Destroy()