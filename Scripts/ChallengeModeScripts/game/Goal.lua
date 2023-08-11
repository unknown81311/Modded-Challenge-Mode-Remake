Goal = class()
Goal.maxParentCount = 1
Goal.maxChildCount = 255
Goal.connectionInput = sm.interactable.connectionType.logic
Goal.connectionOutput = sm.interactable.connectionType.logic
Goal.colorNormal = sm.color.new( 0x189ef5ff )
Goal.colorHighlight = sm.color.new( 0x3caef87ff )

--[[ Client ]]

-- (Event) Called upon creation on client
function Goal.client_onCreate( self )
	self.cl = {}
	self.cl.isActive = self.interactable.active
	if self.data and self.data.onCreateEffect then
		self.cl.onCreateEffect = sm.effect.createEffect( self.data.onCreateEffect, self.interactable )
		self.cl.onCreateEffect:setParameter( "minColor", sm.color.new( 0.0, 0.0, 0.8, 0.0 ) )
		self.cl.onCreateEffect:setParameter( "maxColor", sm.color.new( 0.0, 0.6, 1.0, 8.0 ) )
	end
	if self.data and self.data.activateEffect then
		self.cl.activateEffect = sm.effect.createEffect( self.data.activateEffect, self.interactable )
	end
end

-- (Event) Called upon destruction on client
function Goal.client_onDestroy( self )
	if self.cl.onCreateEffect then
		self.cl.onCreateEffect:destroy()
	end
	if self.cl.activateEffect then
		self.cl.activateEffect:destroy()
	end
end

-- (Event) Called upon every frame. (Same as fps)
function Goal.client_onUpdate( self, dt )
	local wasActive = self.cl.isActive
	self.cl.isActive = self.interactable.active
	if self:cl_isPowered() then
		if self.cl.isActive then
			if self.cl.onCreateEffect and self.cl.onCreateEffect:isPlaying() then
				self.cl.onCreateEffect:stop()
			end
			if not wasActive and self.cl.activateEffect and not self.cl.activateEffect:isPlaying() then
				self.cl.activateEffect:setOffsetRotation( sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), sm.vec3.new( 0, 1, 0 ) ) )
				self.cl.activateEffect:start()
			end
		else
			if self.cl.onCreateEffect and not self.cl.onCreateEffect:isPlaying() then
				self.cl.onCreateEffect:start()
			end
		end
	else
		if self.cl.onCreateEffect and self.cl.onCreateEffect:isPlaying() then
			self.cl.onCreateEffect:stop()
		end
		if self.cl.activateEffect and self.cl.activateEffect:isPlaying() then
			self.cl.activateEffect:stop()
		end
	end
end

function Goal.cl_isPowered( self )
	local parent = self.interactable:getSingleParent()
	if parent then
		return parent.active
	end
	return true
end