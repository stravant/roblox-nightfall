local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Signal = require(game.ReplicatedStorage.Signal)
local ModalManager = require(game.ReplicatedStorage.ModalManager)

local NetmapCamera = {}

local BIND_NAME = "NetmapCameraBind"
-- Dead zone: presses that move less than this stay clicks (no pan)
local DRAG_THRESHOLD_PX = 14

function NetmapCamera.new()
	local this = {}
	
	this.Clicked = Signal.new()
	
	local mIgnoredFirstClick = false
	
	local mCamera = workspace.CurrentCamera
	mCamera.CameraType = Enum.CameraType.Scriptable
	mCamera.FieldOfView = 10
	
	local mZoomLevel = 400
	local MIN_ZOOM = 200
	local MAX_ZOOM = 500
	
	local mCurrentPosition = Vector3.new()
	local LAST_POSITION_COUNT = 30
	local mLastPositions = {}
	for i = 1, LAST_POSITION_COUNT do
		mLastPositions[i] = {tick() - i * 1/60, mCurrentPosition}
	end
	
	local function computeExtraVelocity()
		local firstFewZeroVelocity = true
		for i = LAST_POSITION_COUNT - 4, LAST_POSITION_COUNT - 1 do
			if mLastPositions[i + 1][2] ~= mLastPositions[i][2] then
				firstFewZeroVelocity = false
				break
			end
		end
		if firstFewZeroVelocity then
			return Vector3.new()
		end
		local mTotalVelocity = Vector3.new()
		local mTotalVelocityCount = 0
		for i = LAST_POSITION_COUNT - 20, LAST_POSITION_COUNT - 1 do
			local newPos = mLastPositions[i + 1]
			local lastPos = mLastPositions[i]
			local velocity = (newPos[2] - lastPos[2]) / (newPos[1] - lastPos[1])
			local weight = 1 - (((LAST_POSITION_COUNT - 1) - i) / 22)^0.25
			mTotalVelocity += velocity * weight
			mTotalVelocityCount += weight
		end
		return mTotalVelocity / mTotalVelocityCount
	end
	
	local function applyCamera()
		mCamera.Focus = CFrame.new(mCurrentPosition)
		mCamera.CFrame = CFrame.new(mCurrentPosition) * CFrame.Angles(0, math.pi/4, 0) * CFrame.Angles(-math.pi/4 + 0.25, 0, 0) * CFrame.new(0, 0, mZoomLevel)
	end

	local function setPosition(vec)
		local BOTTOM_EDGE = 60
		local TOP_EDGE = -140
		local LEFT_EDGE = -60
		local RIGHT_EDGE = 550
		local vertical = vec.X + vec.Z
		local horizontal = vec.X - vec.Z
		if vertical > BOTTOM_EDGE then
			local extra = vertical - BOTTOM_EDGE
			vec = Vector3.new(vec.X - 0.5 * extra, vec.Y, vec.Z - 0.5 * extra)
		end
		if vertical < TOP_EDGE then
			local extra = TOP_EDGE - vertical
			vec = Vector3.new(vec.X + 0.5 * extra, vec.Y, vec.Z + 0.5 * extra)
		end
		if horizontal < LEFT_EDGE then
			local extra = LEFT_EDGE - horizontal
			vec = Vector3.new(vec.X + 0.5 * extra, vec.Y, vec.Z - 0.5 * extra)
		end
		if horizontal > RIGHT_EDGE then
			local extra = horizontal - RIGHT_EDGE
			vec = Vector3.new(vec.X - 0.5 * extra, vec.Y, vec.Z + 0.5 * extra)
		end	
		
		mCurrentPosition = vec
		applyCamera()
	end
	
	setPosition(mCurrentPosition)
	
	local function handleWheel(delta)
		if ModalManager:IsModal() then
			return
		end
		mZoomLevel -= delta * 80
		mZoomLevel = math.clamp(mZoomLevel, MIN_ZOOM, MAX_ZOOM)
		setPosition(mCurrentPosition)
	end
	
	local function getUnitRay()
		local mouseAt = UserInputService:GetMouseLocation()
		return mCamera:ViewportPointToRay(mouseAt.X, mouseAt.Y)
	end
	
	local function getMouseHit()
		local unitRay = getUnitRay()
		local scale = -unitRay.Origin.Y / unitRay.Direction.Y
		local hitPoint = unitRay.Origin + unitRay.Direction * scale
		return hitPoint
	end
	
	local mPanStartHit = nil
	local mDownScreenPos = Vector2.new()
	local mDidPan = false
	local mIsPanning = false
	local mPinching = false
	local mPinchStartZoom = mZoomLevel
	local mInertialVelocity = Vector3.new()
	local function button1Down()
		if ModalManager:IsModal() or mPinching then
			return
		end
		mPanStartHit = getMouseHit()
		mDownScreenPos = UserInputService:GetMouseLocation()
		mDidPan = false
		mIsPanning = true
	end
	local function button1Up()
		mPanStartHit = nil
		if not mIgnoredFirstClick then
			mIsPanning = false
			mIgnoredFirstClick = true
			return
		end
		if mDidPan then
			mInertialVelocity = computeExtraVelocity()
		elseif mIsPanning then
			this.Clicked:fire(getUnitRay())
		end
		mIsPanning = false
	end
	local function mousePan()
		if ModalManager:IsModal() or mPinching then
			return
		end
		if mPanStartHit then
			if not mDidPan then
				local mouseAt = UserInputService:GetMouseLocation()
				if (mouseAt - mDownScreenPos).Magnitude < DRAG_THRESHOLD_PX then
					return
				end
				mDidPan = true
				-- Re-anchor at the point the drag actually began so the map
				-- doesn't jump by the dead-zone distance
				mPanStartHit = getMouseHit()
				return
			end
			setPosition(mCurrentPosition - (getMouseHit() - mPanStartHit))
		end
	end
	
	local function intertialPan(dt)
		mInertialVelocity -= mInertialVelocity * 3.0 * dt
		local factor = 100 * dt
		if factor > mInertialVelocity.Magnitude then
			mInertialVelocity = Vector3.new()
		else
			mInertialVelocity -= mInertialVelocity.Unit * factor
		end
		if mInertialVelocity ~= Vector3.new() then
			setPosition(mCurrentPosition + mInertialVelocity * dt)
		end
	end
	
	UserInputService.InputBegan:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject.UserInputType == Enum.UserInputType.Touch then
			button1Down()
		end
	end)
	UserInputService.InputEnded:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject.UserInputType == Enum.UserInputType.Touch then
			button1Up()
		end
	end)
	UserInputService.InputChanged:Connect(function(inputObject: InputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseWheel then
			handleWheel(inputObject.Position.Z)
		elseif inputObject.UserInputType == Enum.UserInputType.MouseMovement then
			mousePan()
		elseif inputObject.UserInputType == Enum.UserInputType.Touch then
			mousePan()
		end
	end)
	UserInputService.TouchPinch:Connect(function(_touchPositions, scale, _velocity, state, gameProcessed)
		if ModalManager:IsModal() then
			return
		end
		if state == Enum.UserInputState.Begin then
			if gameProcessed then
				return
			end
			mPinching = true
			mPinchStartZoom = mZoomLevel
			-- The first finger already started a pan/click gesture: cancel it
			mPanStartHit = nil
			mIsPanning = false
			mDidPan = false
			mInertialVelocity = Vector3.new()
		elseif state == Enum.UserInputState.Change then
			if mPinching then
				mZoomLevel = math.clamp(mPinchStartZoom / scale, MIN_ZOOM, MAX_ZOOM)
				setPosition(mCurrentPosition)
			end
		else
			mPinching = false
		end
	end)
	
	function this:FocusOn(position)
		-- TODO: Animate movement for this
		setPosition(position)
	end
	
	function this:Install()
		-- Re-assert the camera state: the battle camera changes type/FOV/CFrame
		-- while a databattle is up
		mCamera.CameraType = Enum.CameraType.Scriptable
		mCamera.FieldOfView = 10
		setPosition(mCurrentPosition)
		local lastTime = os.clock()
		RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value - 1, function()
			local thisTime = os.clock()
			local dt = thisTime - lastTime
			lastTime = thisTime
			table.remove(mLastPositions, 1)
			table.insert(mLastPositions, {thisTime, mCurrentPosition})
			if not mIsPanning then
				intertialPan(dt)
			end
			-- Re-apply every frame so the handover back from the battle camera
			-- takes effect immediately (its last top-down CFrame would
			-- otherwise stick until the next pan)
			applyCamera()
		end)
	end
	
	function this:Uninstall()
		RunService:UnbindFromRenderStep(BIND_NAME)
	end
	
	return this
end

return NetmapCamera
