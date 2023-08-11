dofile("$GAME_DATA/Scripts/game/Lift.lua")
dofile("challenge_shapes.lua")

ChallengeLift = class( Lift )

function ChallengeLift.server_onCreate( self )
	self.server_challengeHasStarted = false
end

function ChallengeLift.client_onCreate( self )
	self:client_init()
	self.client_challengeHasStarted = false
end

function ChallengeLift.server_onFixedUpdate( self )
	local owner = self.tool:getOwner()
	if owner == nil then
		return
	end
	if self.tool:getOwner():getCharacter() == nil then
		return
	end
	
	local challengeHasStarted = sm.challenge.hasStarted()
	if challengeHasStarted ~= self.server_challengeHasStarted then
		self.server_challengeHasStarted = challengeHasStarted
		self.network:sendToClients( "client_setChallengeHasStarted", self.server_challengeHasStarted )
	end
end

function ChallengeLift.client_onEquippedUpdate( self, primaryState, secondaryState )
	if self.tool:isLocal() and self.equipped and sm.localPlayer.getPlayer():getCharacter() then
		if not self.client_challengeHasStarted then
			local success, raycastResult = sm.localPlayer.getRaycast( 7.5 )
			self:client_interact( primaryState, secondaryState, raycastResult )
		else
			sm.visualization.setCreationVisible( false )
			sm.visualization.setCreationValid( false )
			sm.visualization.setLiftVisible( false )
			sm.visualization.setLiftValid( false )
		end
	end
	return true, false
end

function ChallengeLift.client_setChallengeHasStarted( self, challengeHasStarted )
	self.client_challengeHasStarted = challengeHasStarted
end

function ChallengeLift.checkPlaceable( self, raycastResult )
	local targetShape = raycastResult:getShape()
	if targetShape then
		if targetShape.shapeUuid == obj_interactive_buildarea then
			return true
		end
	end
	return false
end

function ChallengeLift.server_placeLift( self, placeLiftParams )
	if not sm.challenge.hasStarted() then
		sm.player.placeLift( placeLiftParams.player, placeLiftParams.selectedBodies, placeLiftParams.liftPos, placeLiftParams.liftLevel, placeLiftParams.rotationIndex )
	end
end
