-- ArrowLight.lua --

ArrowLight = class()

ArrowLight.maxParentCount = 1
ArrowLight.maxChildCount = 255
ArrowLight.connectionInput = sm.interactable.connectionType.logic
ArrowLight.connectionOutput = sm.interactable.connectionType.logic
ArrowLight.colorNormal = sm.color.new( 0xfffe76ff )
ArrowLight.colorHighlight = sm.color.new( 0xeffffadff )

ArrowLight.arrowFrames = 4
ArrowLight.arrowDelay = 0.125

--[[ Server ]]

-- (Event) Called upon game tick. (40 times a second)
function ArrowLight.server_onFixedUpdate( self, timeStep )
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

-- (Event) Called upon creation on client
function ArrowLight.client_onCreate( self )
	self:client_init()
end

-- (Event) Called when script is refreshed (in [-dev])
function ArrowLight.client_onRefresh( self )
	self:client_init()
end

-- Initialize ArrowLight
function ArrowLight.client_init( self )
	self.hasArrow = false
	self.arrowIndex = 0
	self.arrowDelayProgress = 0
end

function ArrowLight.client_onUpdate( self, dt )
	if self.interactable.active then
		local parent = self.interactable:getSingleParent()
		if parent then
			if parent.active then
				self.hasArrow = true
				if parent.shape.shapeUuid == self.shape.shapeUuid then
					local parentIndex = parent:getUvFrameIndex()
					self.arrowIndex = parentIndex + 1
					if self.arrowIndex >= self.arrowFrames then
						self.arrowIndex = 1
					end
				else
					if self.arrowIndex >= self.arrowFrames 
						or self.arrowIndex <= 1 then
							self.arrowIndex = 1
					end
					self.arrowDelayProgress = self.arrowDelayProgress + dt
					if self.arrowDelayProgress >= self.arrowDelay then
						self.arrowDelayProgress = self.arrowDelayProgress - self.arrowDelay
						self.arrowIndex = self.arrowIndex + 1
					end
				end
			end
		end
	end
	
	if not self.interactable.active then
		self.hasArrow = false
		self.arrowIndex = 0
	end
	
	self:client_setUVFrameIndex( self.arrowIndex )

end

function ArrowLight.client_setUVFrameIndex( self, index )
	self.interactable:setUvFrameIndex( index )
end