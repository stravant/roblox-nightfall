
local UserInputService = game:GetService('UserInputService')

return {
	ScreenWidth = workspace.CurrentCamera.ViewportSize.X;
	ScreenHeight = workspace.CurrentCamera.ViewportSize.Y;
	Touch = UserInputService.TouchEnabled;
}