-- BallTrigger.lua --

BallTrigger = class()

BallTrigger.maxParentCount = 0
BallTrigger.maxChildCount = 255
BallTrigger.connectionInput = sm.interactable.connectionType.none
BallTrigger.connectionOutput = sm.interactable.connectionType.logic
BallTrigger.colorNormal = sm.color.new( 0xff4bc1ff )
BallTrigger.colorHighlight = sm.color.new( 0xfb32adff )

BallTrigger.triggerObject = sm.uuid.new( "88a73e45-6740-4a60-b3cc-fbe4e010eb9f" ) --Ball

--[[ Server ]]

-- (Event) Called upon creation on server
function BallTrigger.server_onCreate( self )

	local size = sm.vec3.new( 1.0, 0.5, 1.0 )
	local filter = sm.areaTrigger.filter.dynamicBody
	self.areaTrigger = sm.areaTrigger.createAttachedBox( self.interactable, size, sm.vec3.new(0.0, 1.0, 0.0), sm.quat.identity(), filter )
	
	self.areaTrigger:bindOnEnter( "trigger_onEnterAndStay" )
	self.areaTrigger:bindOnStay( "trigger_onEnterAndStay" )
end

function BallTrigger.trigger_onEnterAndStay( self, trigger, results )
	if sm.challenge.hasStarted() and sm.exists( self.interactable ) and not self.interactable.active then
		for i, body in ipairs( results ) do
			if body:isDynamic() and #body:getShapes() == 1 then
				for k, shape in ipairs( body:getShapes() ) do
					if shape.shapeUuid == self.triggerObject then
						if shape.color == self.shape.color then

							local shapeCenter = shape:getWorldPosition()
							local selfCenter = self.shape:getWorldPosition() + ( self.shape.at * 0.9375 )
							local distance = (shapeCenter-selfCenter):length()

							if distance < 0.875 then
								local position = self.shape:transformPoint(shape:getWorldPosition())
								local rotation = self.shape:transformRotation(shape:getWorldRotation())

								self.interactable.active = true
								sm.shape.destroyPart( shape )
								sm.areaTrigger.destroy( self.areaTrigger )

								self.areaTrigger = nil
								self.network:sendToClients( "client_activate", { state = true, position = position, rotation = rotation } )
							end

							return
						end
					end
				end
			end
		end
	end
end

function BallTrigger.server_onDestroy( self )
	if self.areaTrigger ~= nil and sm.exists( self.areaTrigger ) then
		sm.areaTrigger.destroy( self.areaTrigger )
	end
end

--[[ Client ]]

-- (Event) Called upon creation on client
function BallTrigger.client_onCreate( self )
	self:client_init()
end

-- (Event) Called when script is refreshed (in [-dev])
function BallTrigger.client_onRefresh( self )
	self:client_init()
end

-- Initialize BallTrigger
function BallTrigger.client_init( self )
	self.client_activeEffect = sm.effect.createEffect( "Balltrigger - Activate", self.interactable )

	self.offsetRotationTarget = sm.vec3.getRotation( sm.vec3.new(0,0,1), sm.vec3.new(0,1,0))
	
	self.pullInFlag = false
	self.pullInTimer = 0.0

	self.effectPosition = sm.vec3.zero()
	self.effectRotation = self.offsetRotationTarget

	self:startAnimation( "Ballsocket_off", 30 )
end

function BallTrigger.client_onUpdate( self, dt )
	if self.pullInFlag then
		self.pullInTimer = self.pullInTimer + dt
		self.effectPosition = sm.vec3.lerp( self.effectPosition, sm.vec3.zero(), 10.0 * dt )
		self.effectRotation = sm.quat.slerp( self.effectRotation, self.offsetRotationTarget, 10.0 * dt )

		self.client_activeEffect:setOffsetPosition( self.effectPosition )
		self.client_activeEffect:setOffsetRotation( self.effectRotation )

		if self.pullInTimer > 1.0 and self.currentAnimation == "Ballsocket_off" then
			self:startAnimation( "Ballsocket_activate", 60 )
		end
	end

	if self.currentAnimation == "Ballsocket_activate" and self.animationProgress >= 1.0 then
		self:startAnimation( "Ballsocket_on", 30 )
	end

	self:updateAnimation( dt )
end

function BallTrigger.client_activate( self, data )
	if data.state then
		self.effectPosition = data.position
		self.effectRotation = data.rotation

		self.client_activeEffect:setOffsetPosition( self.effectPosition )
		self.client_activeEffect:setOffsetRotation( self.effectRotation )

		self.client_activeEffect:setParameter( "Color", self.shape.color )
		
		self.pullInFlag = true
		self.pullInTimer = 0.0		

		self.client_activeEffect:start()
	else
		self.client_activeEffect:stop()
	end
end


function BallTrigger.startAnimation( self, animationName, frames, at )
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

function BallTrigger.updateAnimation( self, dt )
	if self.currentAnimation ~= nil then 
		self.animationProgress = self.animationProgress + dt * self.animationSpeed
		if self.animationProgress < 0.0 then
			self.animationProgress = 0
		end
		self.interactable:setAnimProgress( self.currentAnimation, self.animationProgress )
	end
end