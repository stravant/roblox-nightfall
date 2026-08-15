--!strict
-- Journey PLAYBACK: watch a recorded session play itself back in the real
-- game UI. The netmap camera pans/zooms where the player panned, dialogue
-- lines type out in a corner box, and databattles reconstruct a real
-- GameState/GameView and replay the recorded placements and actions (the
-- battle sim is deterministic given the player's commands, same property
-- the replay validator relies on).
--
-- Timing honors the recorded gaps (scaled by the speed control, long gaps
-- capped) so hesitations FEEL like hesitations without ever stalling the
-- viewer for a minute.
--
-- Best-effort by design: the watcher's own netmap progression state stands
-- in for the recorded player's (we don't record saves), and any battle
-- action that fails to resolve is skipped with a note in the ticker rather
-- than aborting the playback.

local Netmap = require(game.ReplicatedStorage.Netmap)
local Places = require(game.ReplicatedStorage.Places)
local GameState = require(game.ReplicatedStorage.GameState)
local GameController = require(game.ReplicatedStorage.GameController)
local GameView = require(game.ReplicatedStorage.GameView)
local DialogueView = require(game.ReplicatedStorage.DialogueView)
local JourneyRecorder = require(game.ReplicatedStorage.JourneyRecorder)
local SoundManager = require(game.ReplicatedStorage.SoundManager)
local React = require(game.ReplicatedStorage.Packages.React)
local StatefulRoot = require(game.ReplicatedStorage.Components.StatefulRoot)
local WindowsButton = require(game.ReplicatedStorage.Components.WindowsButton)

local e = React.createElement

local kMaxGapSeconds = 5 -- longer recorded gaps compress to this (ticker notes it)
local kSpeeds = { 1, 2, 4 }

local JourneyPlayback = {}

--------------------------------------------------------------------------------
-- Detail-string parsers (exposed for tests)
--------------------------------------------------------------------------------

-- "golemstone 7,10>7,8" -> id, fromX, fromY, toX, toY
function JourneyPlayback.ParseMove(detail: string)
	local id, fx, fy, tx, ty = detail:match("^(%S+) (%d+),(%d+)>(%d+),(%d+)$")
	if not id then
		return nil
	end
	return id, tonumber(fx), tonumber(fy), tonumber(tx), tonumber(ty)
end

-- "golemstone crash 7,8>6,4" -> id, command, fromX, fromY, toX, toY
function JourneyPlayback.ParseAttack(detail: string)
	local id, command, fx, fy, tx, ty = detail:match("^(%S+) (%S+) (%d+),(%d+)>(%d+),(%d+)$")
	if not id then
		return nil
	end
	return id, command, tonumber(fx), tonumber(fy), tonumber(tx), tonumber(ty)
end

-- "hack @4,5" -> id, x, y
function JourneyPlayback.ParsePlace(detail: string)
	local id, x, y = detail:match("^(%S+) @(%d+),(%d+)$")
	if not id then
		return nil
	end
	return id, tonumber(x), tonumber(y)
end

-- "120 studs to 80,-40" -> x, z
function JourneyPlayback.ParsePan(detail: string)
	local x, z = detail:match("to (%-?%d+),(%-?%d+)$")
	if not x then
		return nil
	end
	return tonumber(x), tonumber(z)
end

--------------------------------------------------------------------------------
-- Control bar
--------------------------------------------------------------------------------

type BarState = {
	timeText: string,
	tickerText: string,
	speedText: string,
	pausedText: string,
	onSpeed: () -> (),
	onPause: () -> (),
	onStop: () -> (),
}

local function ControlBar(props: BarState)
	return e("Frame", {
		Name = "PlaybackBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0, 620, 0, 58),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 8,
	}, {
		Title = e("TextLabel", {
			Position = UDim2.new(0, 8, 0, 2),
			Size = UDim2.new(0, 200, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.SourceSansBold,
			TextSize = 14,
			TextColor3 = Color3.fromRGB(120, 255, 120),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 8,
			Text = "JOURNEY PLAYBACK " .. props.timeText,
		}),
		Ticker = e("TextLabel", {
			Position = UDim2.new(0, 8, 0, 18),
			Size = UDim2.new(1, -16, 0, 16),
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 8,
			Text = props.tickerText,
		}),
		SpeedButton = e(WindowsButton, {
			Name = "SpeedButton",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 8, 1, -2),
			Size = UDim2.new(0, 60, 0, 20),
			Text = props.speedText,
			TextSize = 14,
			OnClick = props.onSpeed,
		}),
		PauseButton = e(WindowsButton, {
			Name = "PauseButton",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 76, 1, -2),
			Size = UDim2.new(0, 70, 0, 20),
			Text = props.pausedText,
			TextSize = 14,
			OnClick = props.onPause,
		}),
		StopButton = e(WindowsButton, {
			Name = "StopButton",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -8, 1, -2),
			Size = UDim2.new(0, 110, 0, 20),
			Text = "Stop Playback",
			TextSize = 14,
			OnClick = props.onStop,
		}),
	})
end

--------------------------------------------------------------------------------
-- Playback engine
--------------------------------------------------------------------------------

-- deps: { container, netmapView, topbar, menu }
function JourneyPlayback.new(deps: any, record: any)
	local this = {}

	local mStopped = false
	local mPaused = false
	local mSpeedIndex = 1

	-- Live battle state while a battle segment plays
	local mBattle = nil -- { GameState, Controller, GameView }
	-- Corner dialogue box for recorded conversation lines
	local mDialogue = nil

	local mBarGui = Instance.new("Frame")
	mBarGui.Name = "JourneyPlaybackBar"
	mBarGui.Size = UDim2.new(1, 0, 1, 0)
	mBarGui.BackgroundTransparency = 1
	mBarGui.ZIndex = 8

	local mBar = StatefulRoot.create(mBarGui, ControlBar, {
		timeText = "0:00.0",
		tickerText = "Starting...",
		speedText = "1x",
		pausedText = "Pause",
		onSpeed = function()
			mSpeedIndex = mSpeedIndex % #kSpeeds + 1
			mBar.setState({ speedText = kSpeeds[mSpeedIndex] .. "x" })
		end,
		onPause = function()
			mPaused = not mPaused
			mBar.setState({ pausedText = if mPaused then "Resume" else "Pause" })
		end,
		onStop = function()
			this:Destroy()
		end,
	})

	local function ticker(text: string)
		if not mStopped then
			mBar.setState({ tickerText = text })
		end
	end

	local function teardownBattle()
		if mBattle then
			mBattle.GameView:Destroy()
			mBattle = nil
			deps.topbar:SetStartVisible(false)
			deps.topbar:SetAutoPlaceVisible(false)
			deps.topbar:SetDoneTurnVisible(false)
			deps.topbar:SetUndoVisible(false)
			deps.topbar:SetLeaveVisible(false)
			deps.netmapView:SetVisible(true)
			SoundManager:Play('MainBackgroundLoop')
		end
	end

	function this:Destroy()
		if mStopped then
			return
		end
		mStopped = true
		teardownBattle()
		if mDialogue then
			mDialogue:Destroy()
			mDialogue = nil
		end
		mBar.unmount()
		mBarGui:Destroy()
		JourneyRecorder:SetSuppressed(false)
	end

	-- Find the friendly unit of this definition whose head is at the recorded
	-- position (exact thanks to the recorded head coords)
	local function resolveUnit(id: string, headX: number, headY: number)
		if not mBattle then
			return nil
		end
		for unit in pairs(mBattle.GameState:GetUnits()) do
			if not unit.Enemy and unit.Definition.Id == id
				and unit.Tail[1].x == headX and unit.Tail[1].y == headY then
				return unit
			end
		end
		-- Fallback: any live friendly of the right type (old recordings)
		for unit in pairs(mBattle.GameState:GetUnits()) do
			if not unit.Enemy and unit.Definition.Id == id then
				return unit
			end
		end
		return nil
	end

	-- Battles must act on the player's turn; the recorded gap usually covers
	-- the enemy turn already, but don't act early if it hasn't finished
	local function waitForPlayerTurn()
		local waited = 0
		while mBattle and mBattle.GameState:IsEnemyTurn() and waited < 30 and not mStopped do
			waited += task.wait(0.25)
		end
	end

	local function enterBattle(nodeId: string, events: { any }, startIndex: number)
		teardownBattle()
		local node = Netmap.ById[nodeId]
		local placeData = node and Places[node.PlaceId]
		if not placeData then
			ticker("Unknown battle node " .. nodeId .. "; skipping")
			return
		end
		-- Synthesize an inventory from what the session went on to place
		local counts: { [string]: number } = {}
		for i = startIndex, #events do
			local entry = events[i]
			if entry[2] == "BattleExit" then
				break
			elseif entry[2] == "Place" and entry[3] then
				local id = JourneyPlayback.ParsePlace(entry[3])
				if id then
					counts[id] = (counts[id] or 0) + 1
				end
			end
		end
		local inventory = {}
		for id, count in pairs(counts) do
			table.insert(inventory, { Id = id, Count = count })
		end

		local gameState = GameState.new(placeData, inventory, GameState.ClientDelayFunc)
		local gameController = GameController.new(gameState)
		local gameView = GameView.new(gameState, gameController, nil, deps.topbar)
		-- The watcher must not be able to interfere with the recording's battle
		gameView:SetOnlyAllowClick(0, 0)
		gameView:SetOnlyAllowCommand('invalid')
		gameView:SetOnlyAllowUpload(-1, -1)
		deps.topbar:SetAutoPlaceVisible(false)
		gameView:getGui().Position = UDim2.new(0.5, 0, 0.5, 0)
		gameView:getGui().Parent = deps.container
		deps.netmapView:SetVisible(false)
		SoundManager:Stop('MainBackgroundLoop')
		mBattle = { GameState = gameState, Controller = gameController, GameView = gameView }
	end

	local function dispatch(entry: { any }, events: { any }, index: number)
		local event: string = entry[2]
		local detail: string? = entry[3]

		if event == "NetmapPan" and detail then
			local x, z = JourneyPlayback.ParsePan(detail)
			if x then
				deps.netmapView:PanTo(Vector3.new(x, 0, z))
			end
		elseif event == "NetmapZoom" and detail then
			deps.netmapView:SetZoomLevel(tonumber(detail) or 300)
		elseif event == "NetmapNodeClick" and detail then
			deps.netmapView:HighlightNode(detail)
		elseif event == "DialogueLine" and detail then
			if not mDialogue then
				mDialogue = DialogueView.new()
				mDialogue:SetTutorial()
				mDialogue:SetVisible(true)
				mDialogue:GetGui().Parent = deps.container
			end
			mDialogue:SetText(detail)
		elseif event == "DialogueChoice" then
			if mDialogue then
				mDialogue:SetText("")
			end
		elseif event == "BattleEnter" and detail then
			local nodeId = detail:match("^(%S+)")
			enterBattle(nodeId :: string, events, index)
		elseif event == "Place" and detail and mBattle then
			local id, x, y = JourneyPlayback.ParsePlace(detail)
			if id then
				-- Lift the watcher-interference block just for the injection
				mBattle.GameView:SetOnlyAllowUpload(nil)
				mBattle.GameView:ApplyInitialPlacement({ { x = x, y = y, Id = id } })
				mBattle.GameView:SetOnlyAllowUpload(-1, -1)
			end
		elseif event == "BattleStart" and mBattle then
			mBattle.Controller:StartGame()
		elseif event == "Move" and detail and mBattle then
			waitForPlayerTurn()
			local id, fx, fy, tx, ty = JourneyPlayback.ParseMove(detail)
			if id then
				local unit = resolveUnit(id, fx :: number, fy :: number)
				if unit then
					mBattle.Controller:UnitMove(unit, tx, ty)
				else
					ticker("(couldn't resolve " .. id .. " for a move)")
				end
			end
		elseif event == "Attack" and detail and mBattle then
			waitForPlayerTurn()
			local id, command, fx, fy, tx, ty = JourneyPlayback.ParseAttack(detail)
			if id then
				local unit = resolveUnit(id, fx :: number, fy :: number)
				if unit then
					mBattle.Controller:UnitExecute(unit, command, tx, ty)
				else
					ticker("(couldn't resolve " .. id .. " for an attack)")
				end
			end
		elseif event == "DoneTurn" and mBattle then
			waitForPlayerTurn()
			mBattle.Controller:EndTurn()
		elseif event == "Undo" and mBattle then
			mBattle.Controller:Undo()
		elseif event == "BattleExit" then
			teardownBattle()
		end
		-- Everything else (MenuOpen/Close, Shop*, AutoPlace, FeedbackOpen, ...)
		-- shows in the ticker only
	end

	function this:Play()
		JourneyRecorder:SetSuppressed(true)
		mBarGui.Parent = deps.container
		task.spawn(function()
			local events = record.Events or {}
			local previousT = 0
			for index, entry in ipairs(events) do
				if mStopped then
					return
				end
				-- Honor the recorded gap (speed-scaled, long gaps capped)
				local gap = math.max(0, entry[1] - previousT)
				previousT = entry[1]
				local wait = math.min(gap / kSpeeds[mSpeedIndex], kMaxGapSeconds)
				if gap / kSpeeds[mSpeedIndex] > kMaxGapSeconds then
					ticker(string.format("(... %ds pass ...)", gap))
				end
				local waited = 0
				while waited < wait or mPaused do
					if mStopped then
						return
					end
					waited += task.wait(0.05)
				end
				if mStopped then
					return
				end

				mBar.setState({
					timeText = string.format("%d:%04.1f", math.floor(entry[1] / 60), entry[1] % 60),
				})
				ticker(entry[2] .. (if entry[3] then "  " .. entry[3] else ""))
				local ok, err = pcall(function()
					dispatch(entry, events, index)
				end)
				if not ok then
					ticker("(skipped " .. entry[2] .. ": " .. tostring(err):sub(1, 60) .. ")")
				end
			end
			ticker("Playback finished.")
			task.wait(2)
			if not mStopped then
				this:Destroy()
			end
		end)
	end

	return this
end

return JourneyPlayback
