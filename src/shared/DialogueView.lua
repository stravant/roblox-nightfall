
local Signal = require(game.ReplicatedStorage.Signal)
local SoundManager = require(game.ReplicatedStorage.SoundManager)
local DeviceInfo = require(game.ReplicatedStorage.DeviceInfo)
local WindowsButton = require(game.ReplicatedStorage.WindowsButton)

local DialogueView = {}

function DialogueView.new()
	local this = {}
	
	this.OptionSelected = Signal.new()

	local mGui = script.Dialogue:Clone()
	function this:GetGui()
		return mGui
	end
	
	WindowsButton.new(mGui.ChatBox.Button1)
	WindowsButton.new(mGui.ChatBox.Button2)
	
	-- Note, button 2 is actually the top one in the GUI
	local mHasTwoButtons = false
	mGui.ChatBox.Button1.MouseButton1Click:connect(function()
		if mHasTwoButtons then
			this.OptionSelected:fire(2)
		else
			this.OptionSelected:fire(1)
		end
		SoundManager:Play('SelectUnit')
	end)
	mGui.ChatBox.Button2.MouseButton1Click:connect(function()
		this.OptionSelected:fire(1)
		SoundManager:Play('SelectUnit')
	end)
	
	function this:SetVisible(state)
		mGui.Visible = state
	end
	
	function this:SetUser(name, image)
		mGui.Avatar.Frame.AvatarImage.Image = image
		mGui.Avatar.Username.Text = name
	end
	
	function this:SetText(text, choice1, choice2)
		mGui.ChatBox.Inset.Content.Text = text
		if choice2 then
			mHasTwoButtons = true
			mGui.ChatBox.Button2.Visible = true
			mGui.ChatBox.Button1.Visible = true
			mGui.ChatBox.Button2.Text.Text = choice1
			mGui.ChatBox.Button1.Text.Text = choice2
			mGui.ChatBox.Inset.Size = UDim2.new(1, -10, 1, -98)
		elseif choice1 then
			mHasTwoButtons = false
			mGui.ChatBox.Button2.Visible = false
			mGui.ChatBox.Button1.Visible = true
			mGui.ChatBox.Button1.Text.Text = choice1
			mGui.ChatBox.Inset.Size = UDim2.new(1, -10, 1, -66)
		else
			mGui.ChatBox.Button2.Visible = false
			mGui.ChatBox.Button1.Visible = false
			mGui.ChatBox.Inset.Size = UDim2.new(1, -10, 1, -29)
		end
	end
	
	function this:SetTutorial()
		if DeviceInfo.Touch then
			mGui.ChatBox.AnchorPoint = Vector2.new(1, 1)
			mGui.ChatBox.Position = UDim2.new(1, -10, 1, -10)
			mGui.ChatBox.Size = UDim2.new(0, 300, 0, 130)
			mGui.Avatar.AnchorPoint = Vector2.new(1, 0)
			mGui.Avatar.Position = UDim2.new(1, -10, 0, 10)
		else
			mGui.ChatBox.AnchorPoint = Vector2.new(1, 1)
			mGui.ChatBox.Position = UDim2.new(1, -10, 1, -10)
			mGui.ChatBox.Size = UDim2.new(0, 300, 0, 200)
			mGui.Avatar.Position = UDim2.new(1, -160, 0.5, 5)
		end
		--mGui.ChatBox.Size = UDim2.new(0, 330, 0, 250)
		--mGui.Avatar.Position = UDim2.new(1, -160, 0, 30)
		mGui.ChatBox.WindowTitle.Text = "Game Chat"
		--mGui.Avatar.ZIndex = 4
		mGui.MouseCatcher.Visible = false
		this:SetText("")
	end
	
	function this:ExecuteConversation(conversation)
		this:SetUser(conversation.User, conversation.Image)
		local chatPart = 'main'
		while chatPart ~= 'end' do
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
	
	return this	
end

return DialogueView
