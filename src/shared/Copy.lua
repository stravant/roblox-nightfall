local Copy = {}

function Copy.Deep(tb)
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
	return tb
end

function Copy.Shallow(tb)
	local new = {}
	for k, v in pairs(tb) do
		new[k] = v
	end
	return new
end

return Copy
