-- CharacterSpawner.lua --
dofile( "$SURVIVAL_DATA/Scripts/game/survival_units.lua" )

CharacterSpawner = class()

CharacterSpawner.maxParentCount = 1
CharacterSpawner.maxChildCount = 0
CharacterSpawner.connectionInput = sm.interactable.connectionType.logic
CharacterSpawner.connectionOutput = sm.interactable.connectionType.none
CharacterSpawner.colorNormal = sm.color.new( 0xd84004ff )
CharacterSpawner.colorHighlight = sm.color.new( 0xde5f2eff )

local BotNames =
{
	"#{UNIT_TOTEBOT_GREEN}",
	"#{UNIT_HAYBOT}",
	"#{UNIT_TAPEBOT}",
	"#{UNIT_TAPEBOT_RED}",
	"#{UNIT_FARMBOT}",
	"#{UNIT_WOC}",
	"#{UNIT_GLOWBUG}",
}

local BotSettings = {}
BotSettings["#{UNIT_TOTEBOT_GREEN}"] = { uuid = unit_totebot_green, radius = 0.25, height = 1.25 }
BotSettings["#{UNIT_HAYBOT}"] = { uuid = unit_haybot, radius = 0.5, height = 1.6 }
BotSettings["#{UNIT_TAPEBOT}"] = { uuid = unit_tapebot, radius = 0.3, height = 1.8 }
BotSettings["#{UNIT_TAPEBOT_RED}"] = { uuid = unit_tapebot_red, radius = 0.3, height = 1.8 }
BotSettings["#{UNIT_FARMBOT}"] = { uuid = unit_farmbot, radius = 1.4, height = 3.0 }
BotSettings["#{UNIT_WOC}"] = { uuid = unit_woc, radius = 0.8, height = 1.65 }
BotSettings["#{UNIT_GLOWBUG}"] = { uuid = unit_worm, radius = 0.2, height = 0.45 }

--[[ Server ]]

-- (Event) Called upon creation on server
function CharacterSpawner.server_onCreate( self )
	self.interactable.active = false
	self.spawnedUnits = {}
	self.maxSpawns = 3

	self.saved = self.storage:load()
	if self.saved == nil then
		self.saved = {}
		self.saved.spawntype = BotNames[1]
	end

	self.sv = {}
	self.sv.lastActiveState = false

	self.storage:save( self.saved )
	self.network:setClientData( { spawntype = self.saved.spawntype } )
end

function CharacterSpawner.sv_refreshSpawns( self )
	for i, v in Reverse_ipairs( self.spawnedUnits ) do
		if not sm.exists( v ) then
			table.remove( self.spawnedUnits, i )
		end
	end
end

function CharacterSpawner.sv_spawn( self )
	local yaw = math.atan2( self.shape.up.y, self.shape.up.x ) - math.pi / 2
	local botSetting = BotSettings[self.saved.spawntype]
	local botRadius = botSetting.radius
	local botHeight = botSetting.height
	local margin = 0.1
	local heightAdjustmentMiddlePos = sm.vec3.new( 0, 0, -botHeight * 0.5 )
	local shapeOffset = sm.item.getShapeOffset( self.shape.uuid ).y
	local range = lerp( botRadius, botHeight * 0.5, math.abs( self.shape.at:dot( sm.vec3.new( 0, 0, 1 ) ) ) )
	local spawnOffset = self.shape.at * ( range + shapeOffset + margin ) + heightAdjustmentMiddlePos

	local unitColor = nil
	if self.shape.color ~= sm.item.getShapeDefaultColor( self.shape.uuid ) then
		unitColor = self.shape.color
	end

	local spawned = sm.unit.createUnit( botSetting.uuid, self.shape.worldPosition + spawnOffset, yaw, { color = unitColor } )

	sm.effect.playEffect( "Characterspawner - Activate", self.shape.worldPosition, nil, self.shape.worldRotation )
	
	return spawned
end

-- (Event) Called upon game tick. (40 times a second)
function CharacterSpawner.server_onFixedUpdate( self, timeStep )
	if sm.challenge.hasStarted() then

		--Update active state
		local parent = self.interactable:getSingleParent()
		if parent then
			self.interactable.active = parent.active
		else
			self.interactable.active = true
		end
		
		if self.interactable.active and not self.sv.lastActiveState then
			self:sv_refreshSpawns()
			if #self.spawnedUnits < self.maxSpawns then
				self.spawnedUnits[#self.spawnedUnits+1] = self:sv_spawn()
			end
		end
		self.sv.lastActiveState = self.interactable.active
	end
end


function CharacterSpawner.sv_n_setSpawnType( self, params )
	if self.sv.spawntype ~= params.spawntype then
		self.sv.spawntype = params.spawntype
		self.saved.spawntype = params.spawntype
		self.network:setClientData( { spawntype = params.spawntype } )
		self.storage:save( self.saved )
	end
end

--[[ Client ]]

-- (Event) Called upon creation on client
function CharacterSpawner.client_onCreate( self )
	self.cl = {}
end

function CharacterSpawner.client_onClientDataUpdate( self, clientData )
	self.cl.spawntype = clientData.spawntype
	if self.cl.guiInterface then
		self.cl.guiInterface:setSelectedDropDownItem( "DropDown", self.cl.spawntype )
	end
end

function CharacterSpawner.client_onInteract( self, character, state )
	if state == true then
		self.cl.guiInterface = sm.gui.createGuiFromLayout( "$CONTENT_DATA/Gui/Layouts/Interactable_CharacterSpawner.layout" )
		self.cl.guiInterface:createDropDown( "DropDown", "cl_onDropDownChanged", BotNames )

		if self.cl.spawntype then
			self.cl.guiInterface:setSelectedDropDownItem( "DropDown", self.cl.spawntype )
		end
		
		self.cl.guiInterface:setOnCloseCallback( "cl_onClose" )

		self.cl.guiInterface:open()
	end
end

function CharacterSpawner.cl_onDropDownChanged( self, value )
	if value == self.cl.spawntype then
		return
	end
	self.cl.spawntype = value
	self.network:sendToServer( "sv_n_setSpawnType", { spawntype = value } )
end

function CharacterSpawner.cl_onClose( self )
	self.cl.guiInterface:destroy()
	self.cl.guiInterface = nil
end