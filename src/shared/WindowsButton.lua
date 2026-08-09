local DeviceInfo = require(game.ReplicatedStorage.DeviceInfo)

local WindowsButton = {}

function WindowsButton.new(gui)
	gui.ScaleType = Enum.ScaleType.Slice
	gui.SliceCenter = Rect.new(8,8,8,8)
	gui.Image = 'rbxassetid://1372686003'
	gui.MouseButton1Down:connect(function()
		gui.Image = 'rbxassetid://1372686005'
	end)
	if DeviceInfo.Touch then
		gui.MouseButton1Up:connect(function()
			gui.Image = 'rbxassetid://1372686003'
		end)
	else
		gui.MouseButton1Up:connect(function()
			gui.Image = 'rbxassetid://1372686004'
		end)
		gui.MouseEnter:connect(function()
			gui.Image = 'rbxassetid://1372686004'
		end)
		gui.MouseLeave:connect(function()
			gui.Image = 'rbxassetid://1372686003'
		end)
	end
end

return WindowsButton
