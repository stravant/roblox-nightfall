local module = {}

function module:UseMockData()
	return false
end

function module:PlayTutorial()
	return true
end

function module:HasBeatenAllNodes()
	return false
end

function module:GetInitialCredits()
	return 500
end

return module
