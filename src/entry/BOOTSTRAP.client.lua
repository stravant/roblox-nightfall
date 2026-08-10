

-- Copy in our loading screen
local LoadingGui = game.ReplicatedFirst.TitleScreen:Clone()
LoadingGui.Parent = game.Players.LocalPlayer:WaitForChild('PlayerGui')

-- Kill the loading screen
game.ReplicatedFirst:RemoveDefaultLoadingScreen()

-- Essential preloads that we have to do before the user gets to the home screen
local EssentialPreloadList = {
	'rbxassetid://1445844332', --rbxgameasset://Images/NewBackgroundCentre',
	'rbxassetid://1445844947', --rbxgameasset://Images/NewBackgroundLeft',
	'rbxassetid://1445845291', --rbxgameasset://Images/NewBackgroundRight',
	'rbxassetid://1352772741', --rbxgameasset://Images/UIButton',
	'rbxassetid://1353268980', --rbxgameasset://Images/UIButtonHover',
	'rbxassetid://1353265347', --rbxgameasset://Images/UIDialogue',
	'rbxassetid://1352624214', --rbxgameasset://Images/UserAeacus',
	'rbxassetid://1423259023', --rbxgameasset://Images/NodePharmhaus64',
	'rbxassetid://1423258606', --rbxgameasset://Images/NodeLuckyMonkey64',
	'rbxassetid://1423257835', --rbxgameasset://Images/NodeDrDonut64',
	'rbxassetid://1423259034', --rbxgameasset://Images/NodePED64',
	'rbxassetid://1423258609', --rbxgameasset://Images/NodeHQ64',
	'rbxassetid://1423257836', --rbxgameasset://Images/NodeCelularAutoma64',
	'rbxassetid://1423257394', --rbxgameasset://Images/NodeWarez64',
	'rbxassetid://1350381780', --rbxgameasset://Images/NodeConnections',
}
local FastSpawn = Instance.new('BindableEvent')
FastSpawn.Event:connect(function(f, ...) f(...) end)

-- Preload the essential preloads and update the loading text while doing so
FastSpawn:Fire(function()
	game.ContentProvider:PreloadAsync(EssentialPreloadList)
end)
local startTime = tick()
local TEST = false
while game.ContentProvider.RequestQueueSize > 0 or (TEST and tick() - startTime < 3) do
	local frac = game.ContentProvider.RequestQueueSize / #EssentialPreloadList
	if frac > 1 then
		frac = 1
	end
	frac = 1 - frac
	local dt = tick() - startTime
	local cursor;
	if math.sin(dt*5) > 0 then
		cursor = " "
	else
		cursor = "_"
	end
	LoadingGui.Content.TitleImage.LoadingText.Text = "Loading"..cursor.." "..math.floor(frac * 100).."%"
	wait()
end

-- While we're here... fire off the "nice to have" preloads, but proceed right away before they're done
local NiceToHavePreloadList = {
	'rbxassetid://1338015926', --rbxgameasset://Images/UnitHack',
	'rbxassetid://1338021929', --rbxgameasset://Images/UnitSlingshot',
	'rbxassetid://1335235117', --rbxgameasset://Images/UnitSentinel',
	'rbxassetid://1335176664', --rbxgameasset://Images/UnitSector',
	'rbxassetid://1335178413', --rbxgameasset://Images/UnitJoinerHorizontal',
	'rbxassetid://1335178024', --rbxgameasset://Images/UnitJoinerVertical',
	'rbxassetid://1354410067', --rbxgameasset://Images/TutorialArrow',
	'rbxassetid://1333754686', --rbxgameasset://Images/TileBackground',
	'rbxassetid://1338297982', --rbxgameasset://Images/SelectedCommand',
	'rbxassetid://1335091372', --rbxgameasset://Images/MoveOverlaySimple',
	'rbxassetid://1333910837', --rbxgameasset://Images/MoveOverlayFlash',
	'rbxassetid://1335092647', --rbxgameasset://Images/MoveOverlayDirect',
	'rbxassetid://1335986152', --rbxgameasset://Images/DoneMarker',
	'rbxassetid://1335928206', --rbxgameasset://Images/AttackDamage',
}
spawn(function()
	game:GetService('ContentProvider'):PreloadAsync(NiceToHavePreloadList)
end)
LoadingGui.Content.TitleImage.LoadingText.Text = "> Click to log onto the Netmap! <"
local startTime = tick()
spawn(function()
	while LoadingGui.Parent do
		local dt = tick() - startTime
		if math.sin(dt*5) > -0.3 then
			LoadingGui.Content.TitleImage.LoadingText.TextTransparency = 0
		else
			LoadingGui.Content.TitleImage.LoadingText.TextTransparency = 0.3
		end
		wait()
	end
end)
local mainCn
mainCn = LoadingGui.Content.ClickOverlay.MouseButton1Click:Connect(function()
	mainCn:Disconnect()
	LoadingGui.PreloadCompleted.Value = true
end)










