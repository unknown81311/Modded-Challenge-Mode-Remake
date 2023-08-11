-- ObserverBot.lua --

ObserverBot = class()

--[[ Server ]]

function ObserverBot.server_onCreate( self )
	self.blockTimer = 0
end

-- (Event) Called upon game tick. (40 times a second)
function ObserverBot.server_onFixedUpdate( self, timeStep )
	-- Update active state
	if self.interactable.active then
		if self.blockTimer * ( 40.0 / 1.0 ) > ( 60.0 * ( 1.0 / 30.0 ) ) then
			self.network:sendToClients( "client_takeNote" )
			self.blockTimer = 0
		end
		self.interactable.active = false
	end

	self.blockTimer = self.blockTimer + 1
end

--[[ Client ]]

-- (Event) Called upon creation on client
function ObserverBot.client_onCreate( self )
	self:client_init()
end

-- (Event) Called when script is refreshed (in [-dev])
function ObserverBot.client_onRefresh( self )
	self:client_init()
end

-- Initialize ObserverBot
function ObserverBot.client_init( self )
	self.animationProgress = 0.0
	self.animationSpeed = 0.0

	self.loopTimer = 0.0
	self.turn = 0.0

	self.interactable:setAnimEnabled( "obeserbot_bpose", true )
	self.interactable:setAnimProgress( "obeserbot_bpose", 0.0 )

	self:start_animation( "obeserbot_loop01", 120 )

	self.takeNoteAudioEffect = sm.effect.createEffect( "ObserverBot - Write", self.interactable )
end

-- (Event) Called upon every frame. (Same as fps)
function ObserverBot.client_onUpdate( self, dt )
	
	if 	self.currentAnimation == "obeserbot_loop01" or
		self.currentAnimation == "obeserbot_loop02" then 
		
		self.loopTimer = self.loopTimer + dt
		local integral, fraction = math.modf( self.animationProgress )
		self.animationProgress = fraction
		if integral > 0 then
			sm.effect.playEffect( "ObserverBot - Move", self.shape.worldPosition )
			if self.loopTimer > 10.0 then
				if math.random(2) == 2 then
					self:start_animation( "obeserbot_misc01", 120 )
				else
					self:start_animation( "obeserbot_misc02", 120 )
				end
				self.loopTimer = 0
			end
		end
	end

	if 	self.currentAnimation == "obeserbot_misc01" or
		self.currentAnimation == "obeserbot_misc02" or
		self.currentAnimation == "obeserbot_note" then 

		if self.animationProgress > 1.0 then
			sm.effect.playEffect( "ObserverBot - Move", self.shape.worldPosition )
			if math.random(2) == 2 then
				self:start_animation( "obeserbot_loop01", 120 )
			else
				self:start_animation( "obeserbot_loop02", 120 )
			end
			self.loopTimer = 0
		end
	end

	local position = self.interactable.shape.worldPosition
	local closestPoint = nil
	local closestDistance = 20.0 * 20.0

	local players = sm.player.getAllPlayers()
	for _,player in ipairs( players ) do
		local character = player.character
		if character and player.character:getWorld() == self.shape.body:getWorld() then
			local playerPoint = player:getCharacter().worldPosition
			local distance = (position - playerPoint):length2()
			if distance < closestDistance then
				closestDistance = distance
				closestPoint = playerPoint
			end
		end
	end

	local turnTarget = 0.0
	if closestPoint ~= nil then
		local up = sm.vec3.new( 0.0, 1.0, 0.0 )
		local dir = -self.interactable.shape:transformPoint( closestPoint )

		local dirProjected = ( dir - ( up * ( sm.vec3.dot( up, dir ) ) ) )

		turnTarget = ( math.pi + math.atan2( dirProjected.x, dirProjected.z ) ) / ( math.pi * 2.0 )
	end

	if turnTarget - self.turn > 0.5 then
		self.turn = self.turn+1.0
	elseif turnTarget - self.turn < -0.5 then
		self.turn = self.turn-1.0
	end

	self.turn = sm.util.lerp( self.turn, turnTarget, dt * 5 )
	
	if self.turn > 1.0 then
		self.interactable:setAnimProgress( "obeserbot_bpose", self.turn-1.0 )
	elseif self.turn < 0.0 then
		self.interactable:setAnimProgress( "obeserbot_bpose", self.turn+1.0 )
	else
		self.interactable:setAnimProgress( "obeserbot_bpose", self.turn )
	end

	self:update_animation( dt )
end

function ObserverBot.client_takeNote( self )
	if self.currentAnimation ~= "obeserbot_note" then
		self.takeNoteAudioEffect:start()
		self:start_animation( "obeserbot_note", 60 )
	end
end

function ObserverBot.start_animation( self, animationName, frames, at )
	if self.currentAnimation ~= nil then 
		self.interactable:setAnimEnabled( self.currentAnimation, false )
	end

	if frames == 0 then
		frames = 30.0
	end

	self.currentAnimation = animationName
	self.animationSpeed = 30.0 / frames
	self.animationProgress = at or 0.0
	self.interactable:setAnimEnabled( self.currentAnimation, true )
	self.interactable:setAnimProgress( self.currentAnimation, self.animationProgress )
end

function ObserverBot.update_animation( self, dt )
	if self.currentAnimation ~= nil then 
		self.animationProgress = self.animationProgress + dt * self.animationSpeed
		if self.animationProgress < 0.0 then
			self.animationProgress = 0
		end
		self.interactable:setAnimProgress( self.currentAnimation, self.animationProgress )
	end
end