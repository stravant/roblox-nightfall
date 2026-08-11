--!strict
--[[
	class Signal

	Description:
		Lua-side duplication of the API of Events on Roblox objects. Needed for nicer
		syntax, and to ensure that for local events objects are passed by reference
		rather than by value where possible, as the BindableEvent objects always pass
		their signal arguments by value, meaning tables will be deep copied when that
		is almost never the desired behavior.

	API:
		void fire(...)
			Fire the event with the given arguments.

		Connection connect(Function handler)
			Connect a new handler to the event, returning a connection object that
			can be disconnected.

		... wait()
			Wait for fire to be called, and return the arguments it was given.
--]]

export type Signal = {
	fire: (self: Signal, ...any) -> (),
	connect: (self: Signal, f: (...any) -> ()) -> RBXScriptConnection,
	wait: (self: Signal) -> ...any,
}

local Signal = {}

function Signal.new(): Signal
	local sig = {}

	local mSignaler = Instance.new('BindableEvent')

	-- Each fire's args live under their own index so deferred deliveries of
	-- back-to-back fires can't clobber one another (a single shared slot made
	-- every queued handler see only the LAST fire's args). Entries are
	-- released after the fire's handlers and waiters have run.
	local mArgStore: { [number]: { n: number } } = {}
	local mFireIndex = 0

	function sig:fire(...)
		mFireIndex += 1
		local index = mFireIndex
		mArgStore[index] = table.pack(...)
		mSignaler:Fire(index)
		task.defer(function()
			mArgStore[index] = nil
		end)
	end

	function sig:connect(f)
		if not f then error("connect(nil)", 2) end
		return mSignaler.Event:Connect(function(index)
			local args = mArgStore[index]
			if args then
				f(table.unpack(args, 1, args.n))
			end
		end)
	end

	function sig:wait()
		local index = mSignaler.Event:Wait()
		local args = mArgStore[index]
		assert(args, "Signal arg data missing in wait()")
		return table.unpack(args, 1, args.n)
	end

	return (sig :: any) :: Signal
end

return Signal
