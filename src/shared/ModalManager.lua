local ModalManager = {}

local mModal = false

function ModalManager:SetModal(state)
	mModal = state
end

function ModalManager:IsModal()
	return mModal
end

return ModalManager
