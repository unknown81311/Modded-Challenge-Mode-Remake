ChallengeStarter = class()
ChallengeStarter.poseWeightCount = 1
ChallengeStarter.maxParentCount = 1
ChallengeStarter.maxChildCount = 255
ChallengeStarter.connectionInput = sm.interactable.connectionType.logic
ChallengeStarter.connectionOutput = sm.interactable.connectionType.logic
ChallengeStarter.colorNormal = sm.color.new( 0x189ef5ff )
ChallengeStarter.colorHighlight = sm.color.new( 0x3caef8ff )

-- (Event) Called upon creation on client
function ChallengeStarter.client_onCreate( self )
	self:client_init()
end

-- (Event) Called when script is refreshed (in [-dev])
function ChallengeStarter.client_onRefresh( self )
	self:client_init()
end

-- Initialize ChallengeStarter
function ChallengeStarter.client_init( self )

end

-- (Event) Called upon game tick. (40 times a second)
function ChallengeStarter.server_onFixedUpdate( self, timeStep )
	if not sm.challenge.hasStarted() then
		local parent = self.interactable:getSingleParent()
		if parent then
			self.interactable.active = parent.active
		else
			self.interactable.active = false
		end
	else
		self.interactable.active = true
	end
end

function ChallengeStarter.client_onUpdate( self, dt )
	self.interactable:setPoseWeight( 0, self.interactable.active and 1 or 0 )
end