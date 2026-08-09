local WindowsTabView = {}

function WindowsTabView.new(tabstrip, tabs, mainTab)
	local this = {}

	local mEntries = {}
	local mSelectedEntry = nil

	-- Set current tab
	local function setSelectedTab(data)
		if mSelectedEntry then
			mSelectedEntry.Content.Visible = false
			mSelectedEntry.Tab.ImageRectOffset = Vector2.new(44, 0)
			mSelectedEntry.Tab.ZIndex = 1
		end
		mSelectedEntry = data
		if mSelectedEntry then
			mSelectedEntry.Content.Visible = true
			mSelectedEntry.Tab.ImageRectOffset = Vector2.new(22, 0)
			mSelectedEntry.Tab.ZIndex = 2
		end
	end

	-- Setup
	local mainTabData;
	for _, tab in pairs(tabstrip:GetChildren()) do
		local tabContents = tabs[tab.Name]
		tabContents.Visible = false
		tab.ImageRectOffset = Vector2.new(44, 0)
		tab.ZIndex = 1
		local tabData = {
			Tab = tab;
			Content = tabContents;
		}
		table.insert(mEntries, tabData)
		if tabContents == mainTab then
			mainTabData = tabData
		end
		tab.MouseButton1Click:connect(function()
			setSelectedTab(tabData)
		end)
	end

	-- Select main tab
	if not mainTab then
		error("WindowsTabView | No main tab specified")
	elseif not mainTabData then
		error("WindowsTabView | Main tab mismatch (the tab is dead)")
	end
	setSelectedTab(mainTabData)

	return this
end

return WindowsTabView
