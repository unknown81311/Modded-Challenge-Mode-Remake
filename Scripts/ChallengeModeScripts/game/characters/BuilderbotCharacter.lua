-- BuilderbotCharacter.lua --

BuilderbotCharacter = class( nil )

local movementEffects = "$CONTENT_DATA/Character/Char_builderbot/builderbot_movement_effects.json"

function BuilderbotCharacter.server_onCreate( self ) end

function BuilderbotCharacter.client_onCreate( self )
	print( "-- BuilderbotCharacter created --" )
	self.cl = {}
end

function BuilderbotCharacter.client_onDestroy( self )
	print( "-- BuilderbotCharacter destroyed --" )
end

function BuilderbotCharacter.client_onRefresh( self )
	print( "-- BuilderbotCharacter refreshed --" )
end

function BuilderbotCharacter.client_onGraphicsLoaded( self )
	print("-- BuilderbotCharacter graphics loaded --")
	self.character:setMovementEffects( movementEffects )
	self.graphicsLoaded = true

	self.cl.leftThrusterEffect = sm.effect.createEffect( "Builderbot - Thruster", self.character, "pejnt_l_thruster" )
	self.cl.middleThrusterEffect = sm.effect.createEffect( "Builderbot - Thruster", self.character, "pejnt_m_thruster" )
	self.cl.rightThrusterEffect = sm.effect.createEffect( "Builderbot - Thruster", self.character, "pejnt_r_thruster" )
	self:cl_controlThrusterEffects()
end

function BuilderbotCharacter.client_onGraphicsUnloaded( self )
	self.graphicsLoaded = false

	if self.cl.leftThrusterEffect then
		self.cl.leftThrusterEffect:destroy()
		self.cl.leftThrusterEffect = nil
	end
	if self.cl.middleThrusterEffect then
		self.cl.middleThrusterEffect:destroy()
		self.cl.middleThrusterEffect = nil
	end
	if self.cl.rightThrusterEffect then
		self.cl.rightThrusterEffect:destroy()
		self.cl.rightThrusterEffect = nil
	end
end

function BuilderbotCharacter.cl_controlThrusterEffects( self )
	if self.character == sm.localPlayer.getPlayer().character and sm.localPlayer.isInFirstPersonView() then
		if self.cl.leftThrusterEffect and self.cl.leftThrusterEffect:isPlaying() then
			self.cl.leftThrusterEffect:stop()
		end
		if self.cl.middleThrusterEffect and self.cl.middleThrusterEffect:isPlaying() then
			self.cl.middleThrusterEffect:stop()
		end
		if self.cl.rightThrusterEffect and self.cl.rightThrusterEffect:isPlaying() then
			self.cl.rightThrusterEffect:stop()
		end
	else
		if self.cl.leftThrusterEffect and not self.cl.leftThrusterEffect:isPlaying() then
			self.cl.leftThrusterEffect:start()
		end
		if self.cl.middleThrusterEffect and not self.cl.middleThrusterEffect:isPlaying() then
			self.cl.middleThrusterEffect:start()
		end
		if self.cl.rightThrusterEffect and not self.cl.rightThrusterEffect:isPlaying() then
			self.cl.rightThrusterEffect:start()
		end
	end
end

function BuilderbotCharacter.client_onUpdate( self, deltaTime )
	if not self.graphicsLoaded then
		return
	end

	self:cl_controlThrusterEffects()

	local activeAnimations = self.character:getActiveAnimations()
	sm.gui.setCharacterDebugText( self.character, "" ) -- Clear debug text
	if activeAnimations then
		for i, animation in ipairs( activeAnimations ) do
			if animation.name ~= "" and animation.name ~= "spine_turn" then
				local truncatedWeight = math.floor( animation.weight * 10 + 0.5 ) / 10
				sm.gui.setCharacterDebugText( self.character, tostring( animation.name .. " : " .. truncatedWeight ), false ) -- Add debug text without clearing
			end
		end
	end
end

function BuilderbotCharacter.client_onEvent( self, event )
	self:client_handleEvent( event )
end

function BuilderbotCharacter.client_handleEvent( self, event ) end