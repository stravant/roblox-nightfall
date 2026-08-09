local Places = require(game.ReplicatedStorage.Places)

local TileView = {}

function TileView.new(tileSize, container)
	local this = {}

	local mTiles = {}
	for x = 1, Places.PlaceWidth do
		mTiles[x] = {}
	end

	function this:Set(x, y, tileGui)
		this:Clear(x, y)
		mTiles[x][y] = tileGui
		tileGui.Position = UDim2.new(0, (x-1) * tileSize, 0, (y-1) * tileSize)
		tileGui.Parent = container
	end

	function this:Clear(x, y)
		local tl = mTiles[x][y]
		mTiles[x][y] = nil
		if tl then
			tl:Destroy()
		end
	end

	function this:ClearAll()
		for x = 1, Places.PlaceWidth do
			for i, tile in pairs(mTiles[x]) do
				tile:Destroy()
				mTiles[x][i] = nil
			end
		end
	end

	return this
end

return TileView
