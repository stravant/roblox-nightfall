--!strict
-- Bridges the game's imperative view objects (this:SetFoo(...) style) to a
-- React render tree. The view keeps a plain state table; StatefulRoot.create
-- mounts the component and returns a setState that merges a partial update
-- and re-renders synchronously (legacy root), so imperative call sites can
-- read the resulting GUI right after a Set* call like they could with the
-- old template-mutating code.

local React = require(game.ReplicatedStorage.Packages.React)
local ReactRoblox = require(game.ReplicatedStorage.Packages.ReactRoblox)

-- Sentinel for clearing a state key back to nil via setState.
local None = setmetatable({}, {
	__tostring = function()
		return "<None>"
	end,
})

export type StatefulRoot = {
	setState: (partial: { [string]: any }) -> (),
	getState: () -> { [string]: any },
	unmount: () -> (),
}

local StatefulRoot = {}
StatefulRoot.None = None

-- IMPORTANT: React clears ALL existing children of the root container when the
-- first render commits (clearContainer in the host config). `create`'s host
-- must therefore be exclusively React-owned. When a view mixes React chrome
-- with imperatively-parented siblings in one container, use `createPortaled`,
-- which mounts the root on a detached folder and portals the content into the
-- target — portal targets are never cleared.

function StatefulRoot.create(
	host: Instance,
	component: any,
	initialState: { [string]: any }
): StatefulRoot
	-- Legacy root: renders synchronously on setState, matching the imperative
	-- expectations of the un-converted call sites.
	local createRootFn = (ReactRoblox :: any).createLegacyRoot or ReactRoblox.createRoot
	local root = createRootFn(host)

	local mState = initialState
	local mApplyState: ((any) -> ())? = nil

	local function Wrapper()
		-- Lazy initializer reading mState (not initialState): setState calls
		-- made before the first render flushes (e.g. during the owning view's
		-- construction) must not be lost.
		local state, setState = React.useState(function()
			return mState
		end)
		mApplyState = setState
		return React.createElement(component, state)
	end

	root:render(React.createElement(Wrapper))

	return {
		setState = function(partial: { [string]: any })
			local new = table.clone(mState)
			for key, value in partial do
				if value == None then
					new[key] = nil
				else
					new[key] = value
				end
			end
			mState = new
			if mApplyState then
				mApplyState(new)
			end
		end,
		getState = function()
			return mState
		end,
		unmount = function()
			root:unmount()
		end,
	}
end

function StatefulRoot.createPortaled(
	target: Instance,
	component: any,
	initialState: { [string]: any }
): StatefulRoot
	local createRootFn = (ReactRoblox :: any).createLegacyRoot or ReactRoblox.createRoot
	local host = Instance.new("Folder")
	host.Name = "ReactPortalHost"
	local root = createRootFn(host)

	local mState = initialState
	local mApplyState: ((any) -> ())? = nil

	local function Wrapper()
		local state, setState = React.useState(function()
			return mState
		end)
		mApplyState = setState
		return React.createElement(component, state)
	end

	root:render(ReactRoblox.createPortal(React.createElement(Wrapper), target))

	return {
		setState = function(partial: { [string]: any })
			local new = table.clone(mState)
			for key, value in partial do
				if value == None then
					new[key] = nil
				else
					new[key] = value
				end
			end
			mState = new
			if mApplyState then
				mApplyState(new)
			end
		end,
		getState = function()
			return mState
		end,
		unmount = function()
			root:unmount()
		end,
	}
end

return StatefulRoot
