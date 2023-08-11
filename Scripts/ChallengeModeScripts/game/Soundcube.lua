Soundcube = class()
Soundcube.maxParentCount = 1
Soundcube.maxChildCount = 0
Soundcube.connectionInput = sm.interactable.connectionType.logic
Soundcube.connectionOutput = sm.interactable.connectionType.none
Soundcube.colorNormal = sm.color.new( 0xada9a5ff )
Soundcube.colorHighlight = sm.color.new( 0xcac6c2ff )

-- (Event) Called upon creation on client
function Soundcube.client_onCreate( self )
	self:client_init()
end

-- (Event) Called when script is refreshed (in [-dev])
function Soundcube.client_onRefresh( self )
	self:client_init()
end

-- Initialize Soundcube
function Soundcube.client_init( self )
	self.makingSound = false
	self.effect = sm.effect.createEffect( "Soundcube - Activate", self.interactable )
end

-- (Event) Called upon game tick. (40 times a second)
function Soundcube.server_onFixedUpdate( self, timeStep )
	-- Update active state
	local parent = self.interactable:getSingleParent()
	if parent then
		self.interactable.active = parent.active
	else
		self.interactable.active = false
	end

end

function Soundcube.client_onUpdate( self, dt )

	if self.interactable.active and not self.makingSound then
		self.makingSound = true
		self.effect:start()
	elseif not self.interactable.active and self.makingSound then
		self.makingSound = false
		self.effect:stop()
	end

end