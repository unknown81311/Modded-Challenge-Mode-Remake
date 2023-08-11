Dummy = class()
Dummy.maxParentCount = 0
Dummy.maxChildCount = 0
Dummy.connectionInput = sm.interactable.connectionType.none
Dummy.connectionOutput = sm.interactable.connectionType.none

--Does nothing, but sm.cell.getInteractablesByUuid will only find interactables.

function Dummy.client_onInteract( self )
	print( "Thanks for interacting!" )
end

function Dummy.client_canInteract( self )
	return true
end
