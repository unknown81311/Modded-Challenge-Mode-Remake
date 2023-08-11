-- BuildArea.lua --

BuildArea = class()

BuildArea.maxChildCount = 255
BuildArea.connectionOutput = sm.interactable.connectionType.logic
BuildArea.colorNormal = sm.color.new( 0xff4bc1ff )
BuildArea.colorHighlight = sm.color.new( 0xfb32adff )

-- (Event) Called upon creation on server
function BuildArea.server_onCreate( self )
end

-- (Event) Called when script is refreshed (in [-dev])
function BuildArea.server_onRefresh( self )
end

function BuildArea.server_init( self )
end

--[[ Client ]]

-- (Event) Called upon creation on client
function BuildArea.client_onCreate( self )
	self.hologramEffect = sm.effect.createEffect( "Buildarea - Oncreate", self.interactable )

	self.minColor = sm.color.new( 0.0, 0.0, 0.0, 0.2 )
	self.maxColor = sm.color.new( 0.6, 0.3, 1.0, 0.3 )

	self.minColor2 = sm.color.new( 0.0, 0.0, 0.8, 0.0 )
	self.maxColor2 = sm.color.new( 0.2, 0.6, 1.0, 0.6 )
	
	self.previousState = false
end

-- (Event) Called upon every frame. (Same as fps)
function BuildArea.client_onUpdate( self, dt )

	-- print(self.maxColor)
	self.hologramEffect:setParameter( "minColor", self.minColor )
	self.hologramEffect:setParameter( "maxColor", self.maxColor )
	self.hologramEffect:setParameter( "minColor2", self.minColor2 )
	self.hologramEffect:setParameter( "maxColor2", self.maxColor2 )
	
	if self.interactable.active and not self.hologramEffect:isPlaying() then
		self.hologramEffect:start()
	elseif not self.interactable.active and self.hologramEffect:isPlaying() then
		self.hologramEffect:stop()
	end

end