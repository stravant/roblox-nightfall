local Places = require(game.ReplicatedStorage.Places)
local TileTemplates = require(game.ReplicatedStorage.GameView.TileTemplates)

local UnitsView = {}

function UnitsView.new(tileSize, container)
	local this = {}

	local function signedPow(n, pow)
		if n > 0 then
			return n^pow
		else
			return -((-n)^pow)
		end
	end

	local mFlashUnit = nil
	local mFlashStart = tick()
	local mFlashCn = nil
	local function mFlashTask()
		if not mFlashUnit then
			mFlashCn:disconnect()
			return
		end
		local dt = tick() - mFlashStart
		local tile = mFlashUnit.TailSquares[#mFlashUnit.TailSquares]
		tile.ImageTransparency = 0.5 + 0.4*signedPow(math.sin(dt*15), 0.3)
	end

	function this:SetFlashUnit(unit)
		if not mFlashUnit then
			mFlashCn = game:GetService('RunService').RenderStepped:connect(mFlashTask)
		end
		mFlashStart = tick()
		mFlashUnit = unit
	end

	function this:ClearFlashUnit()
		if mFlashUnit then
			mFlashUnit.TailSquares[#mFlashUnit.TailSquares].ImageTransparency = 0
		end
		mFlashUnit = nil
	end

	local mShowDamageTasks = {}
	local mShowDamageCn = nil
	local function mShowDamageHandler()
		local t = tick()
		for task in pairs(mShowDamageTasks) do
			local dt = t - task.Start
			if dt > 0.2 then
				mShowDamageTasks[task] = nil
				task.Gui:Destroy()
			else
				local f = dt / 0.2
				if f < 0.5 then
					task.Gui.ImageTransparency = 0.3 - 0.3 * ((f - 0.25) / 0.25)^1.4
				else
					task.Gui.ImageTransparency = (1 - ((f - 0.5) / 0.5))^1.3
				end
			end
		end
		if not next(mShowDamageTasks) then
			mShowDamageCn:disconnect()
			mShowDamageCn = nil
		end
	end

	function this:ShowDamage(x, y, color)
		local gui = TileTemplates.UnitSector()
		gui.ImageColor3 = color
		gui.Position = UDim2.new(0, (x-1)*tileSize, 0, (y-1)*tileSize)
		gui.Parent = container
		local task = {
			Gui = gui;
			Start = tick();
		}
		mShowDamageTasks[task] = true
		if not mShowDamageCn then
			mShowDamageCn = game:GetService('RunService').RenderStepped:connect(mShowDamageHandler)
		end
	end


	-- Show sparks on the square targeted for damage. They should be particles
	-- that fly out from the square, probably white, semi-trans
	local mUpdateParticleTasks = {}
	local mUpdateAllParticleTasksCn = nil
	local function updateParticleTask(task)
		--x/y/dirx/diry/velocity/gui

		-- Get the step
		local t = tick()
		local dt = t - task.LastTick
		task.LastTick = t

		-- Time left
		local remaining = math.max(0, task.Remaining - dt)
		task.Remaining = remaining
		local fractionDone = 1 - (remaining / task.Duration)

		-- End if done
		if fractionDone >= 1 then
			-- Kill the particles and remove the task
			for _, particle in pairs(task.Particles) do
				particle.Gui:Destroy()
			end
			mUpdateParticleTasks[task] = nil
		else
			-- Process the particles
			for _, particle in pairs(task.Particles) do
				particle.X = particle.X + particle.DirX * dt * particle.Velocity
				particle.Y = particle.Y + particle.DirY * dt * particle.Velocity
				particle.Gui.Position = UDim2.new(0, particle.X * tileSize, 0, particle.Y * tileSize)
				particle.Gui.BackgroundTransparency = fractionDone^2
			end
		end

	end
	local function mUpdateAllParticleTasks()
		-- Update tasks
		for task, _ in pairs(mUpdateParticleTasks) do
			updateParticleTask(task)
		end

		-- Stop if there's no tasks left... I should really write a pattern for this,
		-- I did it like, 3 times in this view already
		if not next(mUpdateParticleTasks) then
			mUpdateAllParticleTasksCn:disconnect()
			mUpdateAllParticleTasksCn = nil
		end
	end
	function this:ShowDamageSparks(x, y)
		-- Adjust the coordinate to centre-position
		x = x - 0.5
		y = y - 0.5

		-- Make the particles
		local baseDir = math.random()*math.pi*2
		local particles = {}
		for i = 1, 24 do
			local particle = {}


			-- Velocity
			particle.Velocity = 0.5 + (math.random()^1.3)*7

			-- The gui
			local gui = Instance.new('Frame')
			gui.BackgroundColor3 = Color3.new(1, 1, 1)
			gui.BorderSizePixel = 0
			gui.AnchorPoint = Vector2.new(0.5, 0.5)
			local size = 2 + (1 - (particle.Velocity / 7.5)) * 4
			gui.Size = UDim2.new(0, size, 0, size)
			gui.ZIndex = 2
			gui.Position = UDim2.new(0, x*tileSize, 0, y*tileSize)
			gui.Parent = container
			particle.Gui = gui

			-- Direction
			local dir = baseDir + i * 1.61*math.pi*2 + math.random()*0.2
			particle.DirX = math.cos(dir)
			particle.DirY = math.sin(dir)

			-- Initial position
			particle.X = x
			particle.Y = y

			-- Add to list
			table.insert(particles, particle)
		end

		-- Create the task
		local task = {
			Particles = particles;
			LastTick = tick();
			Remaining = 0.6;
			Duration = 0.6;
		}
		mUpdateParticleTasks[task] = true

		-- Start the task runner again if it's not running
		if not mUpdateAllParticleTasksCn then
			mUpdateAllParticleTasksCn = game:GetService('RunService').RenderStepped:connect(mUpdateAllParticleTasks)
		end
	end

	local function setTailSquare(unit, i, coord)
		local sq = unit.TailSquares[i]
		if not sq then
			sq = TileTemplates.UnitSector()
			sq.ImageColor3 = unit.Color
			sq.Parent = unit.TailContainer
			unit.TailSquares[i] = sq
		end
		if unit ~= mFlashUnit then
			sq.ImageTransparency = 0
		end
		sq.Position = UDim2.new(0, (coord.x-1)*tileSize, 0, (coord.y-1)*tileSize)
	end

	local function setVerticalJoiner(unit, i, x, y)
		local sq = unit.VerticalTailJoiners[i]
		if not sq then
			sq = TileTemplates.UnitJoinerVertical()
			sq.ImageColor3 = unit.Color
			sq.Parent = unit.TailContainer
			unit.VerticalTailJoiners[i] = sq
		end
		sq.Position = UDim2.new(0, (x-1)*tileSize, 0, (y-0.5)*tileSize)
	end

	local function setHorizontalJoiner(unit, i, x, y)
		local sq = unit.HorizontalTailJoiners[i]
		if not sq then
			sq = TileTemplates.UnitJoinerHorizontal()
			sq.ImageColor3 = unit.Color
			sq.Parent = unit.TailContainer
			unit.HorizontalTailJoiners[i] = sq
		end
		sq.Position = UDim2.new(0, (x-0.5)*tileSize, 0, (y-1)*tileSize)
	end

	local function clearExtra(unit, tail, vertical, horizontal)
		for i = tail, #unit.TailSquares do
			unit.TailSquares[i]:Destroy()
			unit.TailSquares[i] = nil
		end
		for i = vertical, #unit.VerticalTailJoiners do
			unit.VerticalTailJoiners[i]:Destroy()
			unit.VerticalTailJoiners[i] = nil
		end
		for i = horizontal, #unit.HorizontalTailJoiners do
			unit.HorizontalTailJoiners[i]:Destroy()
			unit.HorizontalTailJoiners[i] = nil
		end
	end

	local function updateTail(unit)
		unit.DoneMarker.Visible = unit.Done and not unit.Enemy
		local nextHorizontal = 1
		local nextVertical = 1
		local lastTail = unit.Tail[1]
		setTailSquare(unit, 1, lastTail)
		unit.HeadPart.Position = UDim2.new(0, (lastTail.x-1)*tileSize, 0, (lastTail.y-1)*tileSize)
		for i = 2, #unit.Tail do
			local coord = unit.Tail[i]
			setTailSquare(unit, i, coord)
			if coord.x == lastTail.x then
				setVerticalJoiner(unit, nextVertical, coord.x, math.min(coord.y, lastTail.y))
				nextVertical = nextVertical + 1
			else
				setHorizontalJoiner(unit, nextHorizontal, math.min(coord.x, lastTail.x), coord.y)
				nextHorizontal = nextHorizontal + 1
			end
			lastTail = coord
		end
		clearExtra(unit, #unit.Tail + 1, nextVertical, nextHorizontal)
	end

	function this:AddUnit(unit)
		unit.TailContainer = Instance.new('Folder', container)
		unit.HeadPart = TileTemplates.UnitSector()
		unit.HeadPart.Name = 'Head'
		unit.HeadPart.ZIndex = 2
		unit.HeadPart.Image = unit.Definition.Image
		unit.HeadPart.Parent = unit.TailContainer
		unit.DoneMarker = TileTemplates.DoneMarker()
		unit.DoneMarker.Visible = false
		unit.DoneMarker.Parent = unit.HeadPart
		unit.TailSquares = {}
		unit.HorizontalTailJoiners = {}
		unit.VerticalTailJoiners = {}
		updateTail(unit)
	end

	function this:RemoveUnit(unit)
		unit.TailSquares = nil
		unit.HorizontalTailJoiners = nil
		unit.VerticalTailJoiners = nil
		unit.TailContainer:Destroy()
		unit.TailContainer = nil
	end

	function this:UpdateUnit(unit)
		updateTail(unit)
	end

	function this:Destroy()
		if mFlashCn then
			mFlashCn:disconnect()
		end
		if mShowDamageCn then
			mShowDamageCn:disconnect()
		end
	end

	return this
end

return UnitsView
