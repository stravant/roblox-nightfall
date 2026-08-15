--!strict
-- In-memory stand-in for DataStoreService (DebugFlags:UseMockData). Data
-- lives for the server session only, but round-trips properly so the
-- save/load/update code paths behave like production (the old mock dropped
-- everything and never invoked UpdateAsync's transform).

local MockDataStore = {}

local mStores: { [string]: any } = {}
local mOrderedStores: { [string]: any } = {}

function MockDataStore:GetDataStore(name: string?)
	local key = "ds_" .. (name or "")
	if mStores[key] then
		return mStores[key]
	end

	local data: { [string]: any } = {}
	local DataStore = {}

	function DataStore:GetAsync(k)
		return data[k]
	end

	function DataStore:SetAsync(k, value)
		data[k] = value
	end

	function DataStore:UpdateAsync(k, transform)
		local new = transform(data[k])
		if new ~= nil then
			data[k] = new
		end
		return new
	end

	-- Single-page key listing (ascending lexicographic, like the real
	-- service); enough for the journey viewer's needs
	function DataStore:ListKeysAsync(prefix, _pageSize)
		local keys = {}
		for k in pairs(data) do
			if not prefix or prefix == "" or k:sub(1, #prefix) == prefix then
				table.insert(keys, k)
			end
		end
		table.sort(keys)
		local page = {}
		for _, k in pairs(keys) do
			table.insert(page, { KeyName = k })
		end
		local result = { IsFinished = true }
		function result:GetCurrentPage()
			return page
		end
		function result:AdvanceToNextPageAsync()
		end
		return result
	end

	mStores[key] = DataStore
	return DataStore
end

function MockDataStore:GetOrderedDataStore(name: string?)
	local key = "ods_" .. (name or "")
	if mOrderedStores[key] then
		return mOrderedStores[key]
	end

	local data: { [string]: number } = {}
	local DataStore = {}

	function DataStore:GetAsync(k)
		return data[k]
	end

	function DataStore:GetSortedAsync(ascending, pageSize)
		local entries = {}
		for k, v in pairs(data) do
			table.insert(entries, { key = k, value = v })
		end
		table.sort(entries, function(a, b)
			if ascending then
				return a.value < b.value
			else
				return a.value > b.value
			end
		end)
		local page = table.move(entries, 1, math.min(#entries, pageSize or #entries), 1, {})

		local result = {}
		function result:GetCurrentPage()
			return page
		end
		return result
	end

	function DataStore:SetAsync(k, value)
		data[k] = value
	end

	mOrderedStores[key] = DataStore
	return DataStore
end

return MockDataStore
