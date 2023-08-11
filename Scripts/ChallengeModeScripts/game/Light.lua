-- Light.lua --

Light = class()

Light.poseWeightCount = 1
Light.maxParentCount = 1
Light.maxChildCount = 255
Light.connectionInput = sm.interactable.connectionType.logic
Light.connectionOutput = sm.interactable.connectionType.logic
Light.colorNormal = sm.color.new( 0xfffe76ff )
Light.colorHighlight = sm.color.new( 0xeffffadff )


--[[ Server ]]

-- (Event) Called upon game tick. (40 times a second)
function Light.server_onFixedUpdate( self, timeStep )
	--Update active state
	if sm.challenge.hasStarted() then
		local parent = self.interactable:getSingleParent()
		if parent then
			self.interactable.active = parent.active
		else
			self.interactable.active = false
		end
	else
		self.interactable.active = false
	end
end

--[[ Client ]]

function Light.client_onUpdate( self, dt )
	self.interactable:setPoseWeight( 0, self.interactable.active and 1 or 0 )
 end