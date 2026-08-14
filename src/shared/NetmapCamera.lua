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
	
local mCamera = workspace.CurrentCamera
	mCamera.CameraType = Enum.CameraType.Scriptable
	mCamera.FieldOfView = 10
	
	local mZoomLevel = 300
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
		if not mInstalled or ModalManager:IsModal() then
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
	
	local function rayHit(unitRay)
		local scale = -unitRay.Origin.Y / unitRay.Direction.Y
		return unitRay.Origin + unitRay.Direction * scale
	end

	local function getMouseHit()
		return rayHit(getUnitRay())
	end

	-- For a touch, use ITS OWN reported position (gui space -> ScreenPointToRay):
	-- GetMouseLocation reflects whichever finger last moved, so with two fingers
	-- down it alternates between them and the pan anchor jumps by the finger
	-- separation. The mouse keeps the GetMouseLocation path.
	local function getInputHit(inputObject: InputObject?)
		if inputObject and inputObject.UserInputType == Enum.UserInputType.Touch then
			return rayHit(mCamera:ScreenPointToRay(inputObject.Position.X, inputObject.Position.Y))
		else
			return getMouseHit()
		end
	end

	local function getInputScreenPos(inputObject: InputObject?): Vector2
		if inputObject and inputObject.UserInputType == Enum.UserInputType.Touch then
			return Vector2.new(inputObject.Position.X, inputObject.Position.Y)
		else
			return UserInputService:GetMouseLocation()
		end
	end

	local mPanStartHit = nil
	-- The touch that owns the current gesture: a second concurrent finger (the
	-- start of a pinch) must not restart or drive the pan
	local mDownInput: InputObject? = nil
	local mDownScreenPos = Vector2.new()
	local mDidPan = false
	local mIsPanning = false
	local mPinching = false
	local mPinchStartZoom = mZoomLevel
	local mInertialVelocity = Vector3.new()
	-- The camera only reacts to input while installed: its connections are
	-- global, and un-gated they would silently pan the hidden netmap camera
	-- during databattles (whose board drags share the same input events)
	local mInstalled = false
	-- In-flight FocusOn glide ({Start, Target, T, Duration}); cancelled by any
	-- user pan/pinch
	local mFocusTween = nil
	local function button1Down(inputObject: InputObject?)
		if not mInstalled or ModalManager:IsModal() or mPinching then
			return
		end
		if mIsPanning then
			return -- extra touch during a gesture: never restart the pan
		end
		mFocusTween = nil
		mDownInput = inputObject
		mPanStartHit = getInputHit(inputObject)
		mDownScreenPos = getInputScreenPos(inputObject)
		mDidPan = false
		mIsPanning = true
	end
	local function button1Up()
		mPanStartHit = nil
		mDownInput = nil
		if mDidPan then
			mInertialVelocity = computeExtraVelocity()
		elseif mIsPanning then
			this.Clicked:fire(getUnitRay())
		end
		mIsPanning = false
	end
	local function mousePan(inputObject: InputObject?)
		if not mInstalled or ModalManager:IsModal() or mPinching then
			return
		end
		if mPanStartHit then
			if not mDidPan then
				local screenAt = getInputScreenPos(inputObject)
				if (screenAt - mDownScreenPos).Magnitude < DRAG_THRESHOLD_PX then
					return
				end
				mDidPan = true
				-- Re-anchor at the point the drag actually began so the map
				-- doesn't jump by the dead-zone distance
				mPanStartHit = getInputHit(inputObject)
				return
			end
			setPosition(mCurrentPosition - (getInputHit(inputObject) - mPanStartHit))
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
			button1Down(inputObject)
		end
	end)
	UserInputService.InputEnded:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 or inputObject.UserInputType == Enum.UserInputType.Touch then
			if inputObject.UserInputType == Enum.UserInputType.Touch and inputObject ~= mDownInput then
				return -- a non-owning finger lifting doesn't end the gesture
			end
			button1Up()
		end
	end)
	UserInputService.InputChanged:Connect(function(inputObject: InputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseWheel then
			handleWheel(inputObject.Position.Z)
		elseif inputObject.UserInputType == Enum.UserInputType.MouseMovement then
			mousePan(inputObject)
		elseif inputObject.UserInputType == Enum.UserInputType.Touch then
			if inputObject == mDownInput then
				mousePan(inputObject)
			end
		end
	end)
	UserInputService.TouchPinch:Connect(function(_touchPositions, scale, _velocity, state, gameProcessed)
		if not mInstalled or ModalManager:IsModal() then
			return
		end
		if state == Enum.UserInputState.Begin then
			if gameProcessed then
				return
			end
			mPinching = true
			mFocusTween = nil
			mPinchStartZoom = mZoomLevel
			-- The first finger already started a pan/click gesture: cancel it
			mPanStartHit = nil
			mDownInput = nil
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
	
	-- animate: glide there over a moment instead of snapping
	function this:FocusOn(position, animate)
		if animate then
			mInertialVelocity = Vector3.new()
			mFocusTween = {
				Start = mCurrentPosition,
				Target = position,
				T = 0,
				Duration = 0.8,
			}
		else
			mFocusTween = nil
			setPosition(position)
		end
	end
	
	function this:Install()
		mInstalled = true
		-- Discard any motion residue so the camera comes back EXACTLY where
		-- it was: pending focus glides, fling inertia, half-finished gestures
		mFocusTween = nil
		mInertialVelocity = Vector3.new()
		mPanStartHit = nil
		mIsPanning = false
		mDidPan = false
		mPinching = false
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
			if mFocusTween then
				mFocusTween.T = math.min(mFocusTween.T + dt, mFocusTween.Duration)
				local alpha = mFocusTween.T / mFocusTween.Duration
				alpha = alpha * alpha * (3 - 2 * alpha) -- smoothstep
				setPosition(mFocusTween.Start:Lerp(mFocusTween.Target, alpha))
				if mFocusTween and mFocusTween.T >= mFocusTween.Duration then
					mFocusTween = nil
				end
			elseif not mIsPanning then
				intertialPan(dt)
			end
			-- Re-apply every frame so the handover back from the battle camera
			-- takes effect immediately (its last top-down CFrame would
			-- otherwise stick until the next pan)
			applyCamera()
		end)
	end
	
	function this:Uninstall()
		mInstalled = false
		RunService:UnbindFromRenderStep(BIND_NAME)
	end
	
	return this
end

return NetmapCamera
