-- PopupAudience.lua --

PopupAudience = class()

PopupAudience.maxParentCount = 1
PopupAudience.maxChildCount = 0
PopupAudience.connectionInput = sm.interactable.connectionType.logic
PopupAudience.connectionOutput = sm.interactable.connectionType.none
PopupAudience.colorNormal = sm.color.new( 0xada9a5ff )
PopupAudience.colorHighlight = sm.color.new( 0xcac6c2ff )

local MovesPerAnimationLoop = 6

--[[ Server ]]

-- (Event) Called upon game tick. (40 times a second)
function PopupAudience.server_onFixedUpdate( self, timeStep )
	local parent = self.interactable:getSingleParent()
	if parent then
		self.interactable.active = parent.active
	else
		self.interactable.active = false
	end
end

--[[ Client ]]

-- (Event) Called upon creation on client
function PopupAudience.client_onCreate( self )
	self:client_init()
end

-- (Event) Called when script is refreshed (in [-dev])
function PopupAudience.client_onRefresh( self )
	self:client_init()
end

-- Initialize PopupAudience
function PopupAudience.client_init( self )
	self.animationProgress = 0.0
	self.animationSpeed = 0.0
	self.celebratingFlag = false
end

-- (Event) Called upon every frame. (Same as fps)
function PopupAudience.client_onUpdate( self, dt )

	if self.interactable.active and not self.celebratingFlag then
		-- Start the celebration
		self.celebratingFlag = true
		self:client_startAnimation( "popupaudience_start", 20 )
	end

	if not self.interactable.active and self.celebratingFlag then
		-- End the celebration
		self.celebratingFlag = false
		self:client_startAnimation( "popupaudience_start", 20, 0.5 )
	end

	if self.celebratingFlag then
		-- Update celebration
		local previousEffectIntegral, _ = math.modf( self.animationProgress * MovesPerAnimationLoop )
		self:client_updateAnimation( dt )
		local currentEffectIntegral, _ = math.modf( self.animationProgress * MovesPerAnimationLoop )
		if previousEffectIntegral ~= currentEffectIntegral then
			sm.effect.playEffect( "ChallengeCrowd - Jump", self.shape.worldPosition )
		end

		local integral, fraction = math.modf( self.animationProgress )
		self.animationProgress = fraction
		if self.currentAnimation == "popupaudience_start" and integral > 0 then
			-- Start loop
			self:client_startAnimation( "popupaudience_loop", 60 )
		end
	else
		-- Play start animation in reverse
		self:client_updateAnimation( -dt )
	end

end

function PopupAudience.client_startAnimation( self, animationName, frames, at )
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

function PopupAudience.client_updateAnimation( self, dt )
	if self.currentAnimation ~= nil then 
		self.animationProgress = self.animationProgress + dt * self.animationSpeed
		if self.animationProgress < 0.0 then
			self.animationProgress = 0
		end
		self.interactable:setAnimProgress( self.currentAnimation, self.animationProgress )
	end
end