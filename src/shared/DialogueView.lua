--!strict
-- React conversion of DialogueView. Public API is unchanged from the template
-- version: DialogueView.new() returns an imperative view object with an
-- OptionSelected signal; the GUI from GetGui() is a host frame whose contents
-- are rendered by React (layout matches ui-reference/ModuleTemplates/DialogueView.json).

local RunService = game:GetService("RunService")

local Signal = require(game.ReplicatedStorage.Signal)
local SoundManager = require(game.ReplicatedStorage.SoundManager)
local DialogueVoice = require(game.ReplicatedStorage.DialogueVoice)
local JourneyRecorder = require(game.ReplicatedStorage.JourneyRecorder)
local DeviceInfo = require(game.ReplicatedStorage.DeviceInfo)
local React = require(game.ReplicatedStorage.Packages.React)
local StatefulRoot = require(game.ReplicatedStorage.Components.StatefulRoot)
local WindowsButton = require(game.ReplicatedStorage.Components.WindowsButton)

local e = React.createElement

local kWindowImage = "rbxassetid://1378189463"
local kWindowSliceCenter = Rect.new(16, 24, 16, 24)
local kWindowImageRectOffset = Vector2.new(0, 0)
local kWindowImageRectSize = Vector2.new(32, 48)
local kInsetImage = "rbxassetid://1378143823"

-- Typewriter pacing: fast per-character reveal with per-character jitter and
-- occasional longer stalls, like text trickling in over a slow serial line
local kTypeBaseDelay = 0.0046 -- seconds per character before jitter
local kTypeJitter = 0.0077 -- up to this much random extra per character
local kTypeStallChance = 0.06 -- odds a character hangs like a dropped packet
local kTypeStallMin = 0.023
local kTypeStallMax = 0.077

-- The standard window chrome title blue (matches the slice texture's band)
local kDefaultUserColor = Color3.fromRGB(0, 0, 128)

type DialogueState = {
	username: string,
	avatarImage: string,
	userColor: Color3,
	text: string,
	hasContent: boolean,
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

	-- ChatBox geometry: vertically centered (the tutorial overrides this
	-- with a compact corner box)
	local chatBoxAnchor = Vector2.new(0.5, 0.5)
	local chatBoxPosition = UDim2.new(0.5, 0, 0.5, 0)
	local chatBoxSize = UDim2.new(0, 480, 0, 190)
	if props.tutorial then
		chatBoxAnchor = Vector2.new(1, 1)
		chatBoxPosition = UDim2.new(1, -10, 1, -10)
		-- Compact corner box: smaller text than the netmap conversations so
		-- the longest tutorial lines still fit the halved height
		if touch then
			chatBoxSize = UDim2.new(0, 300, 0, 90)
		else
			chatBoxSize = UDim2.new(0, 300, 0, 100)
		end
	end

	-- Two stacked choice buttons need a bit more room than the base box
	if props.choice2 then
		chatBoxSize = chatBoxSize + UDim2.new(0, 0, 0, 10)
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

	-- Two-column body in netmap mode: profile pic left, text right. The
	-- tutorial's compact corner box stays text-only.
	local kPicColumn = if props.tutorial then 0 else 104

	local guiInset = game:GetService("GuiService"):GetGuiInset()

	return e(React.Fragment, nil, {
		MouseCatcher = e("ImageButton", {
			AutoButtonColor = false,
			-- Extended past the topbar inset so the dim covers the full
			-- screen (children may render outside their gui's bounds)
			Position = UDim2.new(0, 0, 0, -guiInset.Y),
			Size = UDim2.new(1, 0, 1, guiInset.Y),
			-- Shadowed backdrop: separates the conversation from the world
			-- behind it (hidden in tutorial mode along with the catcher)
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			Image = "",
			Selectable = false,
			Visible = props.mouseCatcherVisible,
		}),
		ChatBox = e("ImageLabel", {
			-- An empty box (no text, no choices) hides outright: the tutorial
			-- clears its corner box between steps and at the battle's end
			Visible = props.hasContent,
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
			-- The character's signature color painted over the chrome
			-- texture's title band (Aeacus keeps the standard blue)
			TitleBar = e("Frame", {
				Position = UDim2.new(0, 3, 0, 3),
				Size = UDim2.new(1, -6, 0, 18),
				BackgroundColor3 = props.userColor,
				BorderSizePixel = 0,
				ZIndex = 1,
			}),
			WindowTitle = e("TextLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 6, 0, 12),
				Size = UDim2.new(1, -12, 0, 30),
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSansBold,
				TextSize = 14,
				TextColor3 = Color3.new(1, 1, 1),
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 2,
				Text = if props.tutorial then props.windowTitle
					elseif props.username ~= "" then props.windowTitle .. " - " .. props.username
					else props.windowTitle,
			}),
			Inset = e("ImageLabel", {
				Position = UDim2.new(0, 5, 0, 25),
				Size = insetSize,
				BackgroundTransparency = 1,
				Image = kInsetImage,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(8, 8, 8, 8),
			}, {
				ProfilePic = if not props.tutorial
					then e("ImageLabel", {
						Position = UDim2.new(0, 6, 0, 6),
						Size = UDim2.new(0, 92, 0, 92),
						-- Desaturated wash of the character color: the
						-- saturated title color wouldn't contrast with
						-- the avatar art
						BackgroundColor3 = props.userColor:Lerp(Color3.new(0.75, 0.75, 0.75), 0.65),
						BorderColor3 = Color3.new(0, 0, 0),
						Image = props.avatarImage,
					})
					else nil,
				Content = e("TextLabel", {
					Position = UDim2.new(0, 4 + kPicColumn, 0, 4),
					Size = UDim2.new(1, -8 - kPicColumn, 1, -8),
					BackgroundTransparency = 1,
					Font = Enum.Font.SourceSans,
					TextSize = if props.tutorial then 15 else 22,
					TextColor3 = Color3.new(0, 0, 0),
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
				TextSize = 20,
				OnClick = props.onButton1,
			}),
			Button2 = e(WindowsButton, {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 16, 1, -40),
				Size = UDim2.new(1, -32, 0, 28),
				Visible = button2Text ~= nil,
				Text = button2Text or "",
				TextSize = 20,
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
	local mUsername = ""

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
		userColor = kDefaultUserColor,
		text = "",
		hasContent = false,
		choice1 = nil,
		choice2 = nil,
		tutorial = false,
		windowTitle = "Netmap Chat",
		mouseCatcherVisible = true,
		-- Note, button 2 is actually the top one in the GUI
		onButton1 = function()
			JourneyRecorder:Record("DialogueChoice", if mHasTwoButtons then "2" else "1")
			if mHasTwoButtons then
				this.OptionSelected:fire(2)
			else
				this.OptionSelected:fire(1)
			end
			SoundManager:Play("SelectUnit")
		end,
		onButton2 = function()
			JourneyRecorder:Record("DialogueChoice", "1")
			this.OptionSelected:fire(1)
			SoundManager:Play("SelectUnit")
		end,
	})

	function this:GetGui()
		return mGui
	end

	function this:SetVisible(state: boolean)
		mGui.Visible = state
		if not state then
			DialogueVoice:Stop()
		end
	end

	function this:SetUser(name: string, image: string, color: Color3?)
		mUsername = name
		mRoot.setState({
			username = name,
			avatarImage = image,
			userColor = color or kDefaultUserColor,
		})
	end

	-- Typewriter reveal, driven imperatively on the Content label via
	-- MaxVisibleGraphemes (React never declares that property, so the writes
	-- are never fought; driving it through setState would re-render every
	-- frame). The full text is always in the label — the cap just reveals it.
	local mTypeToken = 0
	local mTypeCn: RBXScriptConnection? = nil
	local mTypeRandom = Random.new()
	local function stopTypewriter()
		mTypeToken += 1
		if mTypeCn then
			mTypeCn:Disconnect()
			mTypeCn = nil
		end
	end
	local function startTypewriter(text: string)
		stopTypewriter()
		local token = mTypeToken
		local label = mGui:FindFirstChild("Content", true) :: TextLabel?
		if not label then
			return -- not mounted yet: just show the text without the effect
		end
		local total = utf8.len(text) or #text
		label.MaxVisibleGraphemes = 0
		if total == 0 then
			label.MaxVisibleGraphemes = -1
			return
		end
		local shown = 0
		local acc = 0
		local function nextDelay(): number
			local delay = kTypeBaseDelay + mTypeRandom:NextNumber() * kTypeJitter
			if mTypeRandom:NextNumber() < kTypeStallChance then
				delay += mTypeRandom:NextNumber(kTypeStallMin, kTypeStallMax)
			end
			return delay
		end
		local pending = nextDelay()
		mTypeCn = RunService.Heartbeat:Connect(function(dt)
			if token ~= mTypeToken or not label.Parent then
				if mTypeCn then
					mTypeCn:Disconnect()
					mTypeCn = nil
				end
				return
			end
			acc += dt
			while acc >= pending and shown < total do
				acc -= pending
				shown += 1
				pending = nextDelay()
			end
			if shown >= total then
				-- -1 = everything: robust if grapheme count and codepoint
				-- count ever disagree
				label.MaxVisibleGraphemes = -1
				mTypeCn:Disconnect()
				mTypeCn = nil
			else
				label.MaxVisibleGraphemes = shown
			end
		end)
	end

	function this:SetText(text: string, choice1: string?, choice2: string?)
		mHasTwoButtons = choice2 ~= nil
		-- The dialogue text is always the character talking to us (the
		-- player's side only exists as the response buttons, never spoken)
		DialogueVoice:Speak(mUsername, text)
		if text ~= "" then
			-- Journey: dialogue pacing (how long players sit on each line)
			JourneyRecorder:Record("DialogueLine", (mUsername ~= "" and mUsername .. ": " or "") .. text:sub(1, 40))
		end
		mRoot.setState({
			text = text,
			hasContent = text ~= "" or choice1 ~= nil,
			choice1 = choice1 or StatefulRoot.None,
			choice2 = choice2 or StatefulRoot.None,
		})
		startTypewriter(text)
	end

	function this:SetTutorial()
		mRoot.setState({
			tutorial = true,
			windowTitle = "Game Chat",
			mouseCatcherVisible = false,
		})
		this:SetText("")
	end

	-- Returns the terminal target that ended the conversation: plain 'end',
	-- or an 'end:<outcome>' variant the caller can branch on
	function this:ExecuteConversation(conversation)
		this:SetUser(conversation.User, conversation.Image, conversation.Color)
		local chatPart = "main"
		while true do
			local partData = conversation.Parts[chatPart]
			this:SetText(partData.Text, partData.Response1, partData.Response2)
			local choice = this.OptionSelected:wait()
			if choice == 1 then
				chatPart = partData.Target1
			else
				chatPart = partData.Target2
			end
			if chatPart == "end" or chatPart:sub(1, 4) == "end:" then
				return chatPart
			end
		end
	end

	function this:Destroy()
		DialogueVoice:Stop()
		stopTypewriter()
		mRoot.unmount()
		mGui:Destroy()
	end

	return this
end

return DialogueView
