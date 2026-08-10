--!strict
-- React conversion of DialogueView. Public API is unchanged from the template
-- version: DialogueView.new() returns an imperative view object with an
-- OptionSelected signal; the GUI from GetGui() is a host frame whose contents
-- are rendered by React (layout matches ui-reference/ModuleTemplates/DialogueView.json).

local Signal = require(game.ReplicatedStorage.Signal)
local SoundManager = require(game.ReplicatedStorage.SoundManager)
local DeviceInfo = require(game.ReplicatedStorage.DeviceInfo)
local React = require(game.ReplicatedStorage.Packages.React)
local StatefulRoot = require(game.ReplicatedStorage.Components.StatefulRoot)
local WindowsButton = require(game.ReplicatedStorage.Components.WindowsButton)

local e = React.createElement

local kWindowImage = "rbxassetid://1378189463"
local kWindowSliceCenter = Rect.new(16, 24, 16, 24)
local kWindowImageRectOffset = Vector2.new(0, 0)
local kWindowImageRectSize = Vector2.new(32, 48)
local kAvatarBackdropImageRectOffset = Vector2.new(32, 0)
local kInsetImage = "rbxassetid://1378143823"

type DialogueState = {
	username: string,
	avatarImage: string,
	text: string,
	choice1: string?,
	choice2: string?,
	tutorial: boolean,
	windowTitle: string,
	mouseCatcherVisible: boolean,
	onButton1: () -> (),
	onButton2: () -> (),
}

local function DialogueContent(props: DialogueState)
	local touch = DeviceInfo.Touch

	-- ChatBox / Avatar geometry (SetTutorial() in the original mutated these)
	local chatBoxAnchor = Vector2.new(0.5, 0)
	local chatBoxPosition = UDim2.new(0.5, 0, 0.5, -32)
	local chatBoxSize = UDim2.new(0, 480, 0, 190)
	local avatarAnchor = Vector2.new(0, 1)
	local avatarPosition = UDim2.new(0.5, 120, 0.5, -10)
	if props.tutorial then
		chatBoxAnchor = Vector2.new(1, 1)
		chatBoxPosition = UDim2.new(1, -10, 1, -10)
		if touch then
			chatBoxSize = UDim2.new(0, 300, 0, 130)
			avatarAnchor = Vector2.new(1, 0)
			avatarPosition = UDim2.new(1, -10, 0, 10)
		else
			chatBoxSize = UDim2.new(0, 300, 0, 200)
			avatarPosition = UDim2.new(1, -160, 0.5, 5)
		end
	end

	-- Inset shrinks to make room for the visible buttons
	local insetSize
	local button1Text, button2Text
	if props.choice2 then
		insetSize = UDim2.new(1, -10, 1, -98)
		-- Note, button 2 is actually the top one in the GUI
		button2Text = props.choice1
		button1Text = props.choice2
	elseif props.choice1 then
		insetSize = UDim2.new(1, -10, 1, -66)
		button1Text = props.choice1
	else
		insetSize = UDim2.new(1, -10, 1, -29)
	end

	return e(React.Fragment, nil, {
		MouseCatcher = e("ImageButton", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Image = "",
			Selectable = false,
			Visible = props.mouseCatcherVisible,
		}),
		Avatar = e("ImageLabel", {
			AnchorPoint = avatarAnchor,
			Position = avatarPosition,
			Size = UDim2.new(0, 140, 0, 140),
			BackgroundTransparency = 1,
			Image = kWindowImage,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = kWindowSliceCenter,
			ImageRectOffset = kAvatarBackdropImageRectOffset,
			ImageRectSize = kWindowImageRectSize,
		}, {
			Frame = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Size = UDim2.new(0, 150, 0, 100),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
			}, {
				AvatarImage = e("ImageLabel", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 0),
					Size = UDim2.new(0, 150, 0, 150),
					BackgroundTransparency = 1,
					Image = props.avatarImage,
				}),
			}),
			Username = e("TextLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 6, 0, 12),
				Size = UDim2.new(0, 200, 0, 30),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSansBold,
				TextSize = 14,
				TextColor3 = Color3.new(1, 1, 1),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = props.username,
			}),
		}),
		ChatBox = e("ImageLabel", {
			AnchorPoint = chatBoxAnchor,
			Position = chatBoxPosition,
			Size = chatBoxSize,
			ZIndex = 2,
			BackgroundTransparency = 1,
			Image = kWindowImage,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = kWindowSliceCenter,
			ImageRectOffset = kWindowImageRectOffset,
			ImageRectSize = kWindowImageRectSize,
		}, {
			WindowTitle = e("TextLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 6, 0, 12),
				Size = UDim2.new(0, 200, 0, 30),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSansBold,
				TextSize = 14,
				TextColor3 = Color3.new(1, 1, 1),
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = props.windowTitle,
			}),
			Inset = e("ImageLabel", {
				Position = UDim2.new(0, 5, 0, 25),
				Size = insetSize,
				BackgroundTransparency = 1,
				Image = kInsetImage,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(8, 8, 8, 8),
			}, {
				Content = e("TextLabel", {
					Position = UDim2.new(0, 4, 0, 1),
					Size = UDim2.new(1, -5, 1, -1),
					BackgroundTransparency = 1,
					Font = Enum.Font.SourceSans,
					TextSize = 18,
					TextColor3 = Color3.new(0, 0, 0),
					TextStrokeColor3 = Color3.new(1, 1, 1),
					TextStrokeTransparency = 0.9,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					TextWrapped = true,
					Text = props.text,
				}),
			}),
			Button1 = e(WindowsButton, {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 16, 1, -8),
				Size = UDim2.new(1, -32, 0, 28),
				Visible = button1Text ~= nil,
				Text = button1Text or "",
				OnClick = props.onButton1,
			}),
			Button2 = e(WindowsButton, {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 16, 1, -40),
				Size = UDim2.new(1, -32, 0, 28),
				Visible = button2Text ~= nil,
				Text = button2Text or "",
				OnClick = props.onButton2,
			}),
		}),
	})
end

local DialogueView = {}

function DialogueView.new()
	local this = {}

	this.OptionSelected = Signal.new()

	local mHasTwoButtons = false

	local mGui = Instance.new("Frame")
	mGui.Name = "Dialogue"
	mGui.AnchorPoint = Vector2.new(0.5, 0.5)
	mGui.Position = UDim2.new(0.5, 0, 0.5, 0)
	mGui.Size = UDim2.new(1, 0, 1, 0)
	mGui.BackgroundTransparency = 1
	mGui.ZIndex = 4

	local mRoot = StatefulRoot.create(mGui, DialogueContent, {
		username = "",
		avatarImage = "",
		text = "",
		choice1 = nil,
		choice2 = nil,
		tutorial = false,
		windowTitle = "Netmap Chat",
		mouseCatcherVisible = true,
		-- Note, button 2 is actually the top one in the GUI
		onButton1 = function()
			if mHasTwoButtons then
				this.OptionSelected:fire(2)
			else
				this.OptionSelected:fire(1)
			end
			SoundManager:Play("SelectUnit")
		end,
		onButton2 = function()
			this.OptionSelected:fire(1)
			SoundManager:Play("SelectUnit")
		end,
	})

	function this:GetGui()
		return mGui
	end

	function this:SetVisible(state: boolean)
		mGui.Visible = state
	end

	function this:SetUser(name: string, image: string)
		mRoot.setState({
			username = name,
			avatarImage = image,
		})
	end

	function this:SetText(text: string, choice1: string?, choice2: string?)
		mHasTwoButtons = choice2 ~= nil
		mRoot.setState({
			text = text,
			choice1 = choice1 or StatefulRoot.None,
			choice2 = choice2 or StatefulRoot.None,
		})
	end

	function this:SetTutorial()
		mRoot.setState({
			tutorial = true,
			windowTitle = "Game Chat",
			mouseCatcherVisible = false,
		})
		this:SetText("")
	end

	function this:ExecuteConversation(conversation)
		this:SetUser(conversation.User, conversation.Image)
		local chatPart = "main"
		while chatPart ~= "end" do
			local partData = conversation.Parts[chatPart]
			this:SetText(partData.Text, partData.Response1, partData.Response2)
			local choice = this.OptionSelected:wait()
			if choice == 1 then
				chatPart = partData.Target1
			else
				chatPart = partData.Target2
			end
		end
	end

	function this:Destroy()
		mRoot.unmount()
		mGui:Destroy()
	end

	return this
end

return DialogueView
