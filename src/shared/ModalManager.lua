--!strict
-- Tracks whether a modal surface (menu, conversation, shop) is up, so world
-- input (netmap panning/clicks) can be suppressed.

local ModalManager = {}

local mModal = false

function ModalManager:SetModal(state: boolean)
	mModal = state
end

function ModalManager:IsModal(): boolean
	return mModal
end

return ModalManager
