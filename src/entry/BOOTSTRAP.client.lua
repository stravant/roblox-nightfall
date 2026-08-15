-- No custom loading screen: the game goes straight onto the netmap (Setup
-- builds it immediately); the engine's own default loading screen covers the
-- first instants of the join. This script only WARMS assets in the
-- background — nothing here may block anything.

local ContentProvider = game:GetService('ContentProvider')

-- The netmap's imagery (the first thing on screen)
local NetmapPreloadList = {
	'rbxassetid://1445844332', --rbxgameasset://Images/NewBackgroundCentre',
	'rbxassetid://1445844947', --rbxgameasset://Images/NewBackgroundLeft',
	'rbxassetid://1445845291', --rbxgameasset://Images/NewBackgroundRight',
	'rbxassetid://1372686003', --rbxgameasset://Images/UIButton',
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

-- Battle imagery (needed a little later)
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
	ContentProvider:PreloadAsync(NetmapPreloadList)
end)
spawn(function()
	ContentProvider:PreloadAsync(NiceToHavePreloadList)
end)

-- PreloadAsync only fetches assets into the content cache: the engine still
-- decodes and uploads a texture the first time it's actually RENDERED,
-- which shows as pop-in. Render every image as a near-invisible 1x1 pixel
-- in a corner, and keep the gui alive so the textures stay resident.
local warmup = Instance.new('ScreenGui')
warmup.Name = 'ImageWarmup'
warmup.ResetOnSpawn = false
warmup.DisplayOrder = -100
local mWarmedUp = {}
local function addWarmupImage(id)
	if mWarmedUp[id] then
		return
	end
	mWarmedUp[id] = true
	local img = Instance.new('ImageLabel')
	img.BackgroundTransparency = 1
	img.ImageTransparency = 0.99 -- fully transparent risks being culled unrendered
	img.Size = UDim2.new(0, 1, 0, 1)
	img.Position = UDim2.new(0, 0, 1, -1)
	img.Image = id
	img.Parent = warmup
end
for _, id in pairs(NetmapPreloadList) do
	addWarmupImage(id)
end
for _, id in pairs(NiceToHavePreloadList) do
	addWarmupImage(id)
end
warmup.Parent = game.Players.LocalPlayer:WaitForChild('PlayerGui')

-- ...plus every unit image from the definitions (they're small, and the
-- scripts list / shop / battles feel better with them warm; sourcing from
-- Scripts means new units preload automatically). In its own task: it MUST
-- wait for replication before requiring a game module — ReplicatedFirst runs
-- before ReplicatedStorage finishes replicating, and Scripts requiring its
-- own dependencies mid-replication doesn't just fail, the engine caches the
-- module error and breaks every later require of Scripts in the session.
spawn(function()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	local unitImages = {}
	pcall(function()
		for _, def in pairs(require(game.ReplicatedStorage:WaitForChild('Scripts'))) do
			if def.Image and not mWarmedUp[def.Image] then
				table.insert(unitImages, def.Image)
			end
		end
	end)
	if #unitImages > 0 then
		for _, id in pairs(unitImages) do
			addWarmupImage(id)
		end
		ContentProvider:PreloadAsync(unitImages)
	end
end)
