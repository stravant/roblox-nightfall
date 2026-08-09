local API = {}

local id = nil
local remoteEvent = script.ReportGoogleAnalyticsEvent
local helper = script.GoogleAnalyticsHelper
local googleUserTrackingId = game:GetService("HttpService"):GenerateGUID()
local lastTimeGeneratedGoogleUserId = os.time()

function convertNewlinesToVertLine(stack)
	local rebuiltStack = ""
	local first = true
	for line in stack:gmatch("[^\r\n]+") do
		if first then
			rebuiltStack = line
			first = false
		else
			rebuiltStack = rebuiltStack .. " | " .. line
		end
	end
	return rebuiltStack
end

function removePlayerNameFromStack(stack)
	stack = string.gsub(stack, "Players%.[^.]+%.", "Players.<Player>.")
	return stack
end

function setupScriptErrorTracking()
	game:GetService("ScriptContext").Error:connect(function (message, stack)
		API.ReportEvent("Server",
			removePlayerNameFromStack(message) .. " | " .. 
			removePlayerNameFromStack(stack), "none", 1)
	end)
	-- add tracking for clients
	helper.Parent = game.StarterGui
	-- add to any players that are already in game
	for i, c in ipairs(game.Players:GetChildren()) do
		helper:Clone().Parent = (c:WaitForChild("PlayerGui"))
	end
end

function stringifyEvent(category, action, label, value)
	return "GA EVENT: " ..
		"Category: [" .. tostring(category) .. "] " .. 
		"Action: [" .. tostring(action) .. "] " ..
		"Label: [" .. tostring(label) .. "] " ..
		"Value: [" .. tostring(value) .. "]"
end

function printEventInsteadOfActuallySendingIt(category, action, label, value)
	print(stringifyEvent(category, action, label, value))
end

function API.ReportEvent(category, action, label, value)
	local numberValue = tonumber(value)
	if numberValue == nil or numberValue ~= math.floor(numberValue) then
		warn("WARNING: not reporting event because value is not an integer. ", stringifyEvent(category, action, label, value))
		return
	end
	-- Prevent casual abuse by exploiters firing remotes
	if category == nil then
		warn("WARNING: missing category")
		return
	end
	if action == nil then
		warn("WARNING: missing action")
		return
	end
	if label == nil then
		warn("WARNING: missing label")
		return
	end
	value = numberValue
	if game:FindFirstChild("NetworkServer") ~= nil then
		if id == nil then
			warn("WARNING: not reporting event because Init() has not been called")
			return
		end		
		
		-- Try to detect studio start server + player
		if game.CreatorId <= 0 then
			printEventInsteadOfActuallySendingIt(category, action, label, value)
			return
		end
		
		if os.time() - lastTimeGeneratedGoogleUserId > 7200 then
			googleUserTrackingId = game:GetService("HttpService"):GenerateGUID()
			lastTimeGeneratedGoogleUserId = os.time()
		end

		spawn(function()
			local hs = game:GetService("HttpService")
			hs:PostAsync(
				"http://www.google-analytics.com/collect",
				"v=1&t=event&sc=start" ..
				"&tid=" .. id .. 
				"&cid=" .. googleUserTrackingId ..
				"&ec=" .. hs:UrlEncode(category) ..
				"&ea=" .. hs:UrlEncode(action) .. 
				"&el=" .. hs:UrlEncode(label) ..
				"&ev=" .. hs:UrlEncode(value),
				Enum.HttpContentType.ApplicationUrlEncoded)
		end)
	elseif game:FindFirstChild("NetworkClient") ~= nil then
		local evt = game:GetService("ReplicatedStorage"):WaitForChild("ReportGoogleAnalyticsEvent")
		evt:FireServer(category, action, label, value)
	else
		printEventInsteadOfActuallySendingIt(category, action, label, value)
	end
end

function API.Init(userId, config)
	if game:FindFirstChild("NetworkServer") == nil then
		warn("Init() can only be called from game server")
	end
	if id == nil then
		if userId == nil then
			error("Cannot Init with nil Analytics ID")
		end

		id = userId
		remoteEvent.Parent = game:GetService("ReplicatedStorage")
		remoteEvent.OnServerEvent:connect(function(client, ...) 
			API.ReportEvent("Client", ...) 
		end)
		
		setupScriptErrorTracking()
		API.ReportEvent("Server", "Startup", "none", 0)
	else
		error("Attempting to re-initalize Analytics Module")
	end
end

return API
