--!strict
local Copy = {}

function Copy.Deep(tb: { [any]: any }): { [any]: any }
	local new = {}
	for k, v in pairs(tb) do
		if type(k) == 'table' then
			k = Copy.Deep(k)
		end
		if type(v) == 'table' then
			v = Copy.Deep(v)
		end
		new[k] = v
	end
	-- NOTE: this used to `return tb`, silently making every deep copy an
	-- alias of the original
	return new
end

function Copy.Shallow(tb: { [any]: any }): { [any]: any }
	local new = {}
	for k, v in pairs(tb) do
		new[k] = v
	end
	return new
end

return Copy
