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
		local state, setState = React.useState(initialState)
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

return StatefulRoot
