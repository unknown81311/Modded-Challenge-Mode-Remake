ChallengeFinisher = class()
ChallengeFinisher.poseWeightCount = 1
ChallengeFinisher.maxParentCount = 1
ChallengeFinisher.maxChildCount = 255
ChallengeFinisher.connectionInput = sm.interactable.connectionType.logic
ChallengeFinisher.connectionOutput = sm.interactable.connectionType.logic
ChallengeFinisher.colorNormal = sm.color.new( 0x189ef5ff )
ChallengeFinisher.colorHighlight = sm.color.new( 0x3caef8ff )

local FlipTime = 0.5

-- (Event) Called upon game tick. (40 times a second)
function ChallengeFinisher.server_onFixedUpdate( self, timeStep )
	if sm.challenge.hasStarted() then
		local parent = self.interactable:getSingleParent()
		if parent then
			self.interactable.active = parent.active
		else
			self.interactable.active = false
		end
	end
end

function ChallengeFinisher.client_onUpdate( self, dt )
	if self.interactable.active then
		self.flipElapsedTime = self.flipElapsedTime and ( self.flipElapsedTime + dt ) % ( FlipTime * 2 ) or 0
	else
		self.flipElapsedTime = nil
	end

	if self.flipElapsedTime then
		self.interactable:setPoseWeight( 0, self.flipElapsedTime > FlipTime and 0 or 1 )
	else
		self.interactable:setPoseWeight( 0, 0 )
	end
end