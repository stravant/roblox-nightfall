local MockDataStore = {}

function MockDataStore:GetDataStore()
	local DataStore = {}
	
	function DataStore:GetAsync()
		return nil
	end

	function DataStore:SetAsync()

	end	
	
	function DataStore:UpdateAsync()
		
	end
	
	return DataStore
end

function MockDataStore:GetOrderedDataStore()
	local DataStore = {}
	
	function DataStore:GetSortedAsync()
		local result = {}
		
		function result:GetCurrentPage()
			return {}
		end
		
		return result
	end
	
	function DataStore:SetAsync()
		
	end
	
	return DataStore
end
	
return MockDataStore
