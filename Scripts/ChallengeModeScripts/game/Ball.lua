-- Ball.lua --

Ball = class()

function Ball.server_onCreate( self )
	local body = self.shape:getBody()
	self.singleShape = #body:getShapes() == 1
end

function Ball.server_onFixedUpdate( self )
	local body = self.shape:getBody()
	if sm.challenge.hasStarted() and self.singleShape then
		body.destructable = false
		body.buildable = false
		body.paintable = false
		body.connectable = false 
		body.liftable = false
		body.erasable = false
	end
end

function Ball.client_onCreate( self )
	self.glow = 0.0
	
	self.effect = sm.effect.createEffect( "Ball", self.interactable )
	self.effect:start()
end

function Ball.client_onUpdate( self, dt )
	self.glow = self.glow + dt
	self.interactable:setGlowMultiplier( math.abs( math.sin( self.glow ) ) * 0.8 + 0.2 );

	self.effect:setParameter( "Velocity_max_50", self.shape:getBody():getAngularVelocity():length() )
end