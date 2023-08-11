dofile( "$CHALLENGE_DATA/Scripts/challenge/ChallengeBaseWorld.lua")
dofile( "$CHALLENGE_DATA/Scripts/challenge/world_util.lua" )
dofile( "$CHALLENGE_DATA/Scripts/game/challenge_shapes.lua" )
dofile( "$CHALLENGE_DATA/Scripts/game/challenge_tools.lua" )

BuilderWorld = class( ChallengeBaseWorld )
BuilderWorld.terrainScript = "$CHALLENGE_DATA/Scripts/challenge/terrain_challengebuilder.lua"
BuilderWorld.enableSurface = false
BuilderWorld.enableAssets = true
BuilderWorld.enableClutter = false
BuilderWorld.enableNodes = false
BuilderWorld.enableCreations = true
BuilderWorld.enableHarvestables = false
BuilderWorld.enableKinematics = false
BuilderWorld.cellMinX = -6
BuilderWorld.cellMaxX = 5
BuilderWorld.cellMinY = -7
BuilderWorld.cellMaxY = 6

function BuilderWorld.server_onCreate( self )
	ChallengeBaseWorld.server_onCreate( self )
	self.unloadedCells = ( 1 + self.cellMaxX - self.cellMinX ) * ( 1 + self.cellMaxY - self.cellMinY )
	self.playerSpawners = {}
	self.buildAreaTriggers = {}
	sm.storage.saveAndSync( "levelSettings", self.data.settings or {} )
end

function BuilderWorld.server_onRefresh( self )
	print( "BuilderWorld.server_onRefresh" )
end

function BuilderWorld.server_onFixedUpdate( self )
	ChallengeBaseWorld.server_onFixedUpdate( self )

	-- Set builder restrictions
	local bodies = sm.body.getAllBodies()
	for _, body in ipairs( bodies ) do
		body:setBuildable( true )
		body:setErasable( true )
		body:setConnectable( true )
		body:setPaintable( true )
		body:setLiftable( true )
		body:setUsable( true )
		
		body:setDestructable( false )
		body:setConvertibleToDynamic( true )
	end
end

function BuilderWorld.server_onCellCreated( self, x, y )
	self.unloadedCells = self.unloadedCells - 1
	--print( "Cell ("..x..","..y..") loaded! "..self.unloadedCells.." left..." )
	if self.unloadedCells == 0 then
		sm.event.sendToGame( "server_onCellLoadComplete", { world = self.world, x = x, y = y } )
	end
end

function BuilderWorld.server_onInteractableCreated( self, interactable )
	ChallengeBaseWorld.server_onInteractableCreated( self, interactable )
	if( interactable.shape and interactable.shape.shapeUuid == obj_interactive_startposition ) then
		addToArrayIfNotExists( self.playerSpawners, interactable )
	end
	if( interactable.shape and interactable.shape.shapeUuid == obj_interactive_buildarea ) then
		local filter = sm.areaTrigger.filter.dynamicBody + sm.areaTrigger.filter.staticBody -- Find static on the lift
		local halfSize = sm.vec3.new( 6, 4, 6 )
		self.buildAreaTriggers[tostring( interactable.id )] = sm.areaTrigger.createAttachedBox( interactable, halfSize, sm.vec3.new( 0, 4.5, 0 ), sm.quat.identity(), filter )
	end
end

function BuilderWorld.server_onInteractableDestroyed( self, interactable )
	ChallengeBaseWorld.server_onInteractableDestroyed( self, interactable )
	-- Can unly use simple checks like id compare since object is already destroyed
	removeFromArray( self.playerSpawners, function( value ) return value == interactable; end )
	if self.buildAreaTriggers[tostring( interactable.id )] ~= nil then
		self.buildAreaTriggers[tostring( interactable.id )] = nil
	end
end

-- (Event) Called from Game
function BuilderWorld.server_spawnNewCharacter( self, params )
	self:server_spawnCharacter( params )
end

-- (Event) Called from Game
function BuilderWorld.server_spawnCharacter( self, params )
	print( "World: spawnCharacter" )

	for _,player in ipairs( params.players ) do
		self:server_loadSpawners()
		createCharacterOnSpawner( self.world, player, self.playerSpawners, sm.vec3.new( 2, 2, 9.7 ), false, params.build )
		self:server_loadSavedInventory( player )
	end
end

function BuilderWorld.server_loadSavedInventory( self, player )
	-- Set starting items in no items exist
	if g_inventoriesBuildMode[player.id] == nil then
		local inventoryList = {}
		for i = 1, player:getHotbar():getSize() do
			inventoryList[i] = { uuid = sm.uuid.getNil(), quantity = 0 }
		end

		-- Fill in the first hotbar
		inventoryList[1] = { uuid = blk_challenge01, quantity = 1 }
		inventoryList[2] = { uuid = blk_challenge02, quantity = 1 }
		inventoryList[3] = { uuid = obj_interactive_radio, quantity = 1 }
		inventoryList[4] = { uuid = obj_interactive_startposition, quantity = 1 }
		inventoryList[5] = { uuid = obj_interactive_buildarea, quantity = 1 }
		inventoryList[6] = { uuid = obj_interactive_goal, quantity = 1 }
		inventoryList[7] = { uuid = obj_interactive_challengechest, quantity = 1 }
		inventoryList[8] = { uuid = tool_weldtool, quantity = 1 }
		inventoryList[9] = { uuid = tool_lift_creative, quantity = 1 }
		inventoryList[10] = { uuid = tool_connecttool, quantity = 1 }
		
		g_inventoriesBuildMode[player.id] = inventoryList
	end

	-- Add to inventory
	local savedInventory = g_inventoriesBuildMode[player.id]
	if savedInventory then
		sm.container.beginTransaction()
		for i, slot in ipairs( savedInventory ) do
			sm.container.setItem( player:getHotbar(), i - 1, slot["uuid"], slot["quantity"] ) -- container is 0 indexed
		end
		sm.container.endTransaction()
	end

	-- Clear carry
	local carryContainer = player:getCarry()
	sm.container.beginTransaction()
	for i = 0, carryContainer:getSize() - 1 do
		sm.container.setItem( carryContainer, i, sm.uuid.getNil(), 0 )
	end
	sm.container.endTransaction()
end

-- (Event) Called from Game
function BuilderWorld.server_loadWorldContent( self, data )
	print( "World: loadWorldContent" )
	
	--Creations
	for _, creation in ipairs( g_savedCreations ) do
		local creation = sm.creation.importFromString( self.world, creation, sm.vec3.zero(), sm.quat.identity(), true, true )
		for _,body in ipairs(creation) do
			body.destructable = false
		end
	end
	
	sm.event.sendToGame( "server_onFinishedLoadContent" )
end

function BuilderWorld.server_export( self )
	local beginTime = os.clock()
	
	local levelCreations = sm.body.getCreationsFromBodies( sm.body.getAllBodies() )
	local startCreations = {}
	
	-- Add all creations in the build area triggers to startCreations
	for _, areaTrigger in pairs( self.buildAreaTriggers ) do
		local triggerCreations = sm.body.getCreationsFromBodies( areaTrigger:getContents() )
		for _, creation in ipairs( triggerCreations ) do
			startCreations[#startCreations + 1] = creation
		end
	end
	
	-- Filter out creations containing static bodies from startCreations
	removeFromArray( startCreations, function( creation )
		for _, body in ipairs( creation ) do
			if body:isStatic() and not body:isOnLift() then
				return true
			end
		end
		return false
	end )

	-- Put the startCreation bodies in a lookup table
	local startBodies = {}
	for _, creation in ipairs( startCreations ) do
		for _, body in ipairs( creation ) do
			startBodies[tostring( body.id )] = true
		end
	end

	-- Remove from levelCreations if found in startBodies
	removeFromArray( levelCreations, function( creation )
		return startBodies[tostring( creation[1].id )]
	end )

	print( "Exporting challenge level containing "..#levelCreations.." level creations and "..#startCreations.." start creations" )

	local challengeLevel = {}
	challengeLevel.data = {}
	challengeLevel.data.levelCreations = {}
	challengeLevel.data.startCreations = {}
	challengeLevel.data.tiles = { "$CHALLENGE_DATA/Terrain/Tiles/ChallengeBuilderDefault.tile" }
	challengeLevel.data.settings = sm.storage.load( "levelSettings" )

	for i, creation in ipairs( levelCreations ) do
		challengeLevel.data.levelCreations[i] = "$CONTENT_DATA/LevelCreation_"..i..".blueprint"

		local resolvedBlueprintPath = sm.challenge.resolveContentPath( challengeLevel.data.levelCreations[i] )
		print( "Exporting '"..resolvedBlueprintPath.."'" )

		-- Replace with sm.creation.exportToFile?
		local blueprintJsonString = sm.creation.exportToString( creation[1], true, false ) -- First body, exportToString finds the rest
		local blueprint = sm.json.parseJsonString( blueprintJsonString )
		sm.json.save( blueprint, resolvedBlueprintPath )
	end

	for i, creation in ipairs( startCreations ) do
		challengeLevel.data.startCreations[i] = "$CONTENT_DATA/StartCreation_"..i..".blueprint"

		local resolvedBlueprintPath = sm.challenge.resolveContentPath( challengeLevel.data.startCreations[i] )
		print( "Exporting '"..resolvedBlueprintPath.."'" )

		-- Replace with sm.creation.exportToFile?
		local blueprintJsonString = sm.creation.exportToString( creation[1], true, true ) -- First body, exportToString finds the rest
		local blueprint = sm.json.parseJsonString( blueprintJsonString )
		sm.json.save( blueprint, resolvedBlueprintPath )
	end


	local challengeLevelPath = sm.challenge.resolveContentPath( "$CONTENT_DATA/challengeLevel.json" )
	print( "Exporting '"..challengeLevelPath.."'" )
	print( challengeLevel )
	sm.json.save( challengeLevel, challengeLevelPath )
	sm.challenge.takePicturesForMenu()
	--sm.challenge.takePicture( 8192, 8192 )

	local endTime = os.clock()
	print( "Export time: "..( endTime - beginTime ) * 1000 )
end

function BuilderWorld.server_test( self )
	self:server_export()
	local challengeLevel = sm.json.open( sm.challenge.resolveContentPath( "$CONTENT_DATA/challengeLevel.json" ) )
	sm.event.sendToGame( "server_startTest", challengeLevel.data )
end

function BuilderWorld.client_onCreate( self )
	ChallengeBaseWorld.client_onCreate( self )
	self.floorEffect = sm.effect.createEffect( "BuildMode - Floor" )
	self.floorEffect:start()
end

function BuilderWorld.client_onDestroy( self )
	self.floorEffect:stop()
end

function BuilderWorld.client_showSetting( self, params )
	sm.gui.chatMessage( params )
end
