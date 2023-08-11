dofile( "$CONTENT_DATA/Scripts/ChallengeModeScripts/challenge/ChallengeBaseWorld.lua")
dofile( "$CONTENT_DATA/Scripts/ChallengeModeScripts/challenge/world_util.lua" )
dofile( "$CONTENT_DATA/Scripts/ChallengeModeScripts/game/challenge_shapes.lua" )
dofile( "$CONTENT_DATA/Scripts/ChallengeModeScripts/game/challenge_tools.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/WaterManager.lua" )

ChallengeWorld = class( ChallengeBaseWorld )
ChallengeWorld.terrainScript = "$CONTENT_DATA/Scripts/ChallengeModeScripts/challenge/terrain_challenge.lua"
ChallengeWorld.enableSurface = false
ChallengeWorld.enableAssets = true
ChallengeWorld.enableClutter = false
ChallengeWorld.enableNodes = true
ChallengeWorld.enableCreations = true
ChallengeWorld.enableHarvestables = true
ChallengeWorld.enableKinematics = true
ChallengeWorld.cellMinX = -32
ChallengeWorld.cellMaxX = 32
ChallengeWorld.cellMinY = -32
ChallengeWorld.cellMaxY = 32

ChallengeWorld.audioPosition = sm.vec3.new( 0, 258, 162 )

function ChallengeWorld.server_onCreate( self )
	ChallengeBaseWorld.server_onCreate( self )
	self.waterManager = WaterManager()
	self.waterManager:sv_onCreate( self )

	self.challengeStarted = false
	self.challengeCompleted = false
	self.allowAutoSave = false
	self.latestSaveTick = sm.game.getCurrentTick()
	self.tutorialStage = "Done"
	self.loadingWorld = true
	self.challengeStarters = {}

	self.enableHealth = getSettingValue( self.data.settings, "enable_health" )
end

function ChallengeWorld.client_onCreate( self )
	ChallengeBaseWorld.client_onCreate( self )
	if self.waterManager == nil then
		assert( not sm.isHost )
		self.waterManager = WaterManager()
	end
	self.waterManager:cl_onCreate()

	self.startedEffectTriggered = false
	self.completedEffectTriggered = false
	self.audio = sm.effect.createEffect( "Supervisor - Generic" )
	self.audio:setPosition( self.audioPosition )
	self.audio:start()

	if g_survivalHud and not g_survivalHud:isActive() then
		g_survivalHud:open()
	end
end

function ChallengeWorld.server_onFixedUpdate( self )
	ChallengeBaseWorld.server_onFixedUpdate( self )

	--if true then return end

	self.waterManager:sv_onFixedUpdate()

	-- Clean up picked up items from dropped items
	local currentTick = sm.game.getCurrentTick() 
	for idx, droppedItem in reverse_ipairs( g_droppedItems ) do
		if currentTick > droppedItem.tick and not sm.exists( droppedItem.hvs ) then
			table.remove( g_droppedItems, idx )
		end
	end

	if not self.challengeCompleted and self.challengeStarted then
		for i, goal in ipairs( self.goals ) do
			if goal.active == false and self.goalPreviousStates[tostring(goal.id)] == true then
				local areaTriggerContents = self.goalAreaTriggers[i]:getContents()
				self:trigger_onEnterGoal( self.goalAreaTriggers[i], areaTriggerContents )
			end
			self.goalPreviousStates[tostring(goal.id)] = goal.active
		end
	end
	
	if not self.challengeStarted and #self.challengeStarters > 0 and not self.loadingWorld then
		for _, challengeStarter in ipairs( self.challengeStarters ) do
			if challengeStarter.active then
				self:server_startChallenge()
			end
		end
	end

	if self.challengeStarted and not self.challengeCompleted and #self.challengeFinishers > 0 and not self.loadingWorld then
		for _, challengeFinisher in ipairs( self.challengeFinishers ) do
			if challengeFinisher.active then
				local victoryParams = { showWinnerName = false, winnerName = "", canSaveCreation = #self.chests == 1 }
				self.challengeCompleted = true
				sm.event.sendToGame( "server_onChallengeCompleted", victoryParams )
			end
		end
	end

	if self.allowAutoSave and not self.loadingWorld then
		local allBodies = sm.body.getAllBodies()
		
		--Filter out the level
		local playerCreationBodies = {}
		for i, body in ipairs( allBodies ) do
			if body:isBuildable() then
				playerCreationBodies[#playerCreationBodies+1] = body
			end
		end
		
		--Check if any player creations have been changed
		local shouldSave = false
		for _, body in ipairs( playerCreationBodies ) do
			if body:hasChanged( self.latestSaveTick ) then
				shouldSave = true
				print("change in creation")
				break
			end
		end
		
		--Check if the contents of the starting chest has been changed
		if not shouldSave then
			if self.chest then
				local startingChestContainer = self.chest:getContainer( 0 )
				if startingChestContainer:hasChanged( self.latestSaveTick ) then
					shouldSave = true
					print("change in chest")
				end
			end
		end
		
		--Check if the contents of a player's inventory has been changed
		if not shouldSave then
			local players = sm.player.getAllPlayers()
			for i, player in ipairs( players ) do
				local inventoryContainer = player:getInventory()
				if inventoryContainer:hasChanged( self.latestSaveTick ) then
					shouldSave = true
					print("change in inventory")
					break
				end
			end
		end
		
		if shouldSave then
			self.latestSaveTick = sm.game.getCurrentTick()
			self:server_saveWorldContent( playerCreationBodies )
		end
	end

	if self.tutorialStage == "Done" then
		-- nothing
	elseif self.tutorialStage == "Intro" then
		self.tutorialIntroTimer = self.tutorialIntroTimer + 1
		-- Start tutorial after 10 ticks
		if self.tutorialIntroTimer > 10 then
			self.tutorialStage = "FindChest"
		end
	elseif self.tutorialStage == "FindChest" then
		if self.chest then
			local container = self.chest:getContainer( 0 )
			if container then
				if not container:isEmpty() then
					self.tutorialChest = self.chest
					self.tutorialChestTick = sm.game.getCurrentTick()
					self.tutorialStage = "Chest"
					self.network:sendToClients( "client_onSetTutorialArrow", { target = self.tutorialChest } )
				else
					self.tutorialStage = "FindSeat"
				end
			else
				self.tutorialStage = "FindSeat"
			end
		else
			self.tutorialStage = "FindSeat"
		end

	elseif self.tutorialStage == "Chest" then
		if self.tutorialChest then
			local container = self.tutorialChest:getContainer( 0 )
			if container then
				if container:hasChanged( self.tutorialChestTick ) then
					self.tutorialChest = self.chest
					self.tutorialStage = "FindSeat"
					self.network:sendToClients( "client_onStopTutorialArrow" )
				end
			else
				self.tutorialStage = "FindSeat"
			end
		else
			self.tutorialStage = "FindSeat"
		end

	elseif self.tutorialStage == "FindSeat" then
		self.tutorialSeat = findSteering( sm.body.getAllBodies() )
		if self.tutorialSeat then
			self.tutorialSeatTick = sm.game.getCurrentTick()
			self.tutorialStage = "Seat"
			self.network:sendToClients( "client_onSetTutorialArrow", { target = self.tutorialSeat } )
		else
			-- End the tutorial
			self.tutorialStage = "Done"
		end
	elseif self.tutorialStage == "Seat" then
		if self.tutorialSeat == nil or not sm.exists( self.tutorialSeat ) or self.tutorialSeat.body:hasChanged( self.tutorialSeatTick ) then
			-- End the tutorial
			self.tutorialStage = "Done"
			self.network:sendToClients( "client_onStopTutorialArrow" )
		end
	end

end

function ChallengeWorld.server_onCellCreated( self, x, y )
	print("CELL CREATED", x, y)
	--if self.loaded_cells == nil then self.loaded_cells = 1 else self.loaded_cells = self.loaded_cells + 1 end

	self.waterManager:sv_onCellLoaded( x, y )
	--print(self.loaded_cells)
	--if self.loaded_cells == (65 * 65) then
	if x == 0 and y == 0 then
		ChallengeWorld.server_onCellCreatedFinish( self, x, y )

		sm.event.sendToGame("server_worldReadyForPlayers")

		self.loadingWorld = false
	end
	--end
end

function ChallengeWorld.server_onCellCreatedFinish( self, x, y )

	if self.challengeStarters == nil then self.challengeStarters = {} end
	if self.playerSpawners == nil then self.playerSpawners = {} end
	if self.startAreaTriggers == nil then self.startAreaTriggers = {} end
	if self.buildAreas == nil then self.buildAreas = {} end
	if self.chests == nil then self.chests = {} end
	if self.challengeFinishers == nil then self.challengeFinishers = {} end
	if self.goalAreaTriggers == nil then self.goalAreaTriggers = {} end
	if self.goalPreviousStates == nil then self.goalPreviousStates = {} end
	if self.goals == nil then self.goals = {} end
	if self.observerBots == nil then self.observerBots = {} end

	for _,body in pairs(sm.body.getAllBodies()) do
		for _,shape in pairs(body:getShapes()) do
			
			-- Find challenge starters
			if shape.uuid == obj_interactive_challenge_starter then
				table.insert(self.challengeStarters, shape:getInteractable())
			end

			-- Find challenge finishers
			if shape.uuid == obj_interactive_challenge_finishblock then
				table.insert(self.challengeFinishers, shape:getInteractable())
			end	
			
			-- Find start positions
			if shape.uuid == obj_interactive_startposition then
				local spawner = shape:getInteractable()
				local spawnDir = -spawner.shape:getUp()
				table.insert(self.playerSpawners, {
					pos = spawner.shape.worldPosition + spawner.shape:getAt() * 0.825,
					pitch = math.asin( spawnDir.z ),
					yaw = math.atan2( spawnDir.x, -spawnDir.y )
				})
			end
			
			-- Find chest
			if shape.uuid == obj_interactive_challengechest then
				table.insert(self.chests, shape:getInteractable())
			end
			
			-- Filter
			local filter = sm.areaTrigger.filter.character + sm.areaTrigger.filter.dynamicBody

			-- Find build areas
			if shape.uuid == obj_interactive_buildarea then
				table.insert(self.buildAreas, shape:getInteractable())
			end
			
			-- Find goals
			if shape.uuid == obj_interactive_goal then
				table.insert(self.goals, shape:getInteractable())
			end

			if shape.uuid == obj_interactive_smallgoal then
				local smallGoal = shape:getInteractable()
				local nextIndex = #self.goals+1
				self.goals[nextIndex] = smallGoal
				local halfSize = sm.vec3.new( 0.375, 0.25, 0.375 )
				self.goalAreaTriggers[nextIndex] = sm.areaTrigger.createAttachedBox( smallGoal, halfSize, sm.vec3.new( 0, 0.5, 0 ), sm.quat.identity(), filter )
				self.goalAreaTriggers[nextIndex]:bindOnEnter( "trigger_onEnterGoal" )
				self.goalPreviousStates[tostring(smallGoal.id)] = true
			end

			-- Find Observer Bots
			if shape.uuid == char_challenge_observerbot then
				table.insert(self.observerBots, shape:getInteractable())
			end
		end
	end

	if #self.chests == 1 then
		self.chest = self.chests[1] -- Needed for tutorial arrow
	end

	for i, buildArea in ipairs( self.buildAreas ) do
		buildArea.active = true
		local halfSize = sm.vec3.new( 6, 4, 6 )
		self.startAreaTriggers[i] = sm.areaTrigger.createAttachedBox( buildArea, halfSize, sm.vec3.new( 0, 4.5, 0 ), sm.quat.identity(), filter )
		self.startAreaTriggers[i]:bindOnExit( "trigger_onExitStart" )
	end
	
	for i,goal in ipairs( self.goals ) do
		local halfSize = sm.vec3.new( 6, 4, 6 )
		self.goalAreaTriggers[i] = sm.areaTrigger.createAttachedBox( goal, halfSize, sm.vec3.new( 0, 4.5, 0 ), sm.quat.identity(), filter )
		self.goalAreaTriggers[i]:bindOnEnter( "trigger_onEnterGoal" )
		self.goalPreviousStates[tostring(goal.id)] = true
	end


	-- Kill effect box
	local rotation = sm.quat.identity()

	local halfSize = sm.vec3.new( 8192, 8192, 1024 )
	local position = sm.vec3.new( 0.0, 0.0, -1024.0 )
	self.killWarningAreaTrigger = sm.areaTrigger.createBox( halfSize, position, rotation, sm.areaTrigger.filter.character )
	self.killWarningAreaTrigger:bindOnEnter( "trigger_onEnterKillWarningBox" )
	
	-- Kill box -Z
	local halfSize = sm.vec3.new( 8192, 8192, 1024 )
	local position = sm.vec3.new( 0.0, 0.0, -1056.0 )
	self.killAreaTriggerNZ = sm.areaTrigger.createBox( halfSize, position, rotation, filter )
	self.killAreaTriggerNZ:bindOnEnter( "trigger_onEnterKillBox" )
	
	-- Kill box +Z
	local halfSize = sm.vec3.new( 8192, 8192, 1024 )
	local position = sm.vec3.new( 0.0, 0.0, 1024.0 + ( ( -90.0 + 995.0 ) * 0.5 ) )
	self.killAreaTriggerPZ = sm.areaTrigger.createBox( halfSize, position, rotation, filter )
	self.killAreaTriggerPZ:bindOnEnter( "trigger_onEnterKillBox" )
	
	-- Kill box +Y
	local halfSize = sm.vec3.new( 8192, 1024, 8192 )
	local position = sm.vec3.new( 0.0, 1024.0 + ( ( 298.0 + 680.0 ) * 0.5 ), 0.0 )
	self.killAreaTriggerPY = sm.areaTrigger.createBox( halfSize, position, rotation, filter )
	self.killAreaTriggerPY:bindOnEnter( "trigger_onEnterKillBox" )
	
	-- Kill box -Y
	local halfSize = sm.vec3.new( 8192, 1024, 8192 )
	local position = sm.vec3.new( 0.0, -1024.0 - ( ( 298.0 + 600.0 ) * 0.5 ), 0.0 )
	self.killAreaTriggerNY = sm.areaTrigger.createBox( halfSize, position, rotation, filter )
	self.killAreaTriggerNY:bindOnEnter( "trigger_onEnterKillBox" )
	
	-- Kill box +X
	local halfSize = sm.vec3.new( 1024, 8192, 8192 )
	local position = sm.vec3.new( 1024.0 + ( 795.0 * 0.5 ), 0.0, 0.0 )
	self.killAreaTriggerPX = sm.areaTrigger.createBox( halfSize, position, rotation, filter )
	self.killAreaTriggerPX:bindOnEnter( "trigger_onEnterKillBox" )
	
	-- Kill box -X
	local halfSize = sm.vec3.new( 1024, 8192, 8192 )
	local position = sm.vec3.new( -1024.0 - ( 795.0 * 0.5 ), 0.0, 0.0 )
	self.killAreaTriggerNX = sm.areaTrigger.createBox( halfSize, position, rotation, filter )
	self.killAreaTriggerNX:bindOnEnter( "trigger_onEnterKillBox" )

	sm.event.sendToGame( "server_onCellLoadComplete", { world = self.world } )

	if g_tutorial then
		self.tutorialIntroTimer = 0
		self.tutorialStage = "Intro"
	end

	-- Recreate dropped items
	if g_droppedItems ~= nil then
		for _, droppedItem in ipairs( g_droppedItems ) do
			droppedItem.hvs = sm.harvestable.createHarvestable( sm.uuid.new( "97fe0cf2-0591-4e98-9beb-9186f4fd83c8" ), droppedItem.pos, sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), sm.vec3.new( 0, 0, 1 ) ) )
			droppedItem.hvs:setParams( { uuid = droppedItem.uuid, quantity = droppedItem.quantity } )
		end
	end
end

function ChallengeWorld.server_onCellLoaded( self, x, y )
	--print("CELL LOADED", x, y)
	self.waterManager:sv_onCellReloaded( x, y )
	self:server_onCellCreatedFinish( x, y )
end

function ChallengeWorld.server_onCellUnloaded( self, x, y )
	self.waterManager:sv_onCellUnloaded( x, y )
end

-- (Event) Called from Game
function ChallengeWorld.server_spawnNewCharacter( self, params )
	if self.tutorialStage == "Chest" and self.tutorialChest then
		self.network:sendToClients( "client_onSetTutorialArrow", { target = self.tutorialChest } )
	elseif self.tutorialStage == "Seat" and self.tutorialSeat then
		self.network:sendToClients( "client_onSetTutorialArrow", { target = self.tutorialSeat } )
	end

	params.playCutscene = true
	self:server_spawnCharacter( params )
end


function ChallengeWorld.server_spawnCharacter( self, params )
	print("World: spawnCharacter")
	for _, player in ipairs( params.players ) do
		CreateCharacterOnSpawner( self.world, player, self.playerSpawners, sm.vec3.new( 2, 2, 9.7 ), self.enableHealth, params.build )
		self:server_loadSavedInventory( player )
		self.network:sendToClients( "client_spawned", { player = player, playCutscene = params.playCutscene } )
	end
end

function ChallengeWorld.server_loadSavedInventory( self, player )

	-- Set starting items if no items exist
	if g_inventoriesPlayMode[player.id] == nil then
		local inventoryList = {}
		local inventory = player:getInventory()
		for i = 1, inventory:getSize() do
			inventoryList[i] = { uuid = sm.uuid.getNil(), quantity = 0 }
		end

		print( tool_lift_creative )
		print( tool_challengelift )
		print( tool_sledgehammer_creative )
		print( tool_connecttool )
		print( tool_painttool )
		print( tool_weldtool )
		print( tool_handbook )
		print( tool_spudgun )
		
		local index = 2
		inventoryList[1] = { uuid = sm.uuid.new("55abf9f8-5fd5-44c9-bd1e-207ca3bb9864"), quantity = 1 }

		if getSettingValue( self.data.settings, "enable_handbook" ) then
			inventoryList[index] = { uuid = tool_handbook, quantity = 1 }
			index = index + 1
		end
		if getSettingValue( self.data.settings, "enable_lift" ) then
			inventoryList[index] = { uuid = tool_challengelift, quantity = 1 }
			index = index + 1
		end
		if getSettingValue( self.data.settings, "enable_sledgehammer" ) then
			inventoryList[index] = { uuid = tool_sledgehammer_creative, quantity = 1 }
			index = index + 1
		end
		if getSettingValue( self.data.settings, "enable_connecttool" ) then
			inventoryList[index] = { uuid = tool_connecttool, quantity = 1 }
			index = index + 1
		end
		if getSettingValue( self.data.settings, "enable_painttool" ) then
			inventoryList[index] = { uuid = tool_painttool, quantity = 1 }
			index = index + 1
		end
		if getSettingValue( self.data.settings, "enable_weldtool" ) then
			inventoryList[index] = { uuid = tool_weldtool, quantity = 1 }
			index = index + 1
		end
		if getSettingValue( self.data.settings, "enable_spudgun" ) then
			inventoryList[index] = { uuid = tool_spudgun, quantity = 1 }
			index = index + 1
		end
		
		if getSettingValue( self.data.settings, "enable_client_toilet" ) then
			if player.id ~= 1 then
				inventoryList[index] = { uuid = obj_interactive_toilet, quantity = 1 }
				index = index + 1
			end
		end
		
		g_inventoriesPlayMode[player.id] = inventoryList
	end

	-- Add to inventory
	local savedInventory = g_inventoriesPlayMode[player.id]
	if savedInventory then
		sm.container.beginTransaction()
		for i, slot in ipairs( savedInventory ) do
			sm.container.setItem( player:getInventory(), i - 1, slot["uuid"], slot["quantity"] ) -- container is 0 indexed
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
function ChallengeWorld.server_loadWorldContent( self, data )
	print("World: loadWorldContent")
	self.allowAutoSave = true
	
	--Player inventory
	local players = sm.player.getAllPlayers()
	for _, player in ipairs( players ) do
		self:server_loadSavedInventory( player )
	end

	--Creations
	if g_savedCreations ~= nil then -- g_savedCreations can be nil if the challenge is started with the ChallengeStarter and nothing has been built
		for _, creation in ipairs( g_savedCreations ) do
			local creation = sm.creation.importFromString( self.world, creation, sm.vec3.zero(), sm.quat.identity(), true, true )
			for _,body in ipairs(creation) do
				body.destructable = false
			end
		end
	end

	--Chests
	sm.container.beginTransaction()
	for index, savedChest in ipairs( g_savedChests ) do
		for slot, item in ipairs( savedChest ) do
			sm.container.setItem( self.chests[index]:getContainer(), slot - 1, sm.uuid.new( item["uuid"] ), item["quantity"] ) -- container is 0 indexed
		end
	end
	sm.container.endTransaction()
	
	sm.event.sendToGame( "server_onFinishedLoadContent" )
	self.loadingWorld = false
end

function ChallengeWorld.server_saveWorldContent( self, playerCreationBodies )
	print("World: saveWorldContent")
	
	local players = sm.player.getAllPlayers()
	
	--Player inventory and position
	g_inventoriesPlayMode = {}
	for i, player in ipairs( players ) do
		local inventoryList = {}
		local inventoryContainer = player:getInventory()
		for i = 1, inventoryContainer:getSize() do
			local item = inventoryContainer:getItem( i - 1 ) -- container is 0 indexed
			inventoryList[i] = { uuid = item.uuid, quantity = item.quantity }
		end
		g_inventoriesPlayMode[player.id] = inventoryList
	end
	
	--Creations
	g_savedCreations = {}
	local playerCreations = sm.body.getCreationsFromBodies( playerCreationBodies )
	for i, creation in pairs( playerCreations ) do
		local body = creation[1] -- First body in creation
		local blueprintJson = sm.creation.exportToString( body, true, body:isOnLift() )
		g_savedCreations[#g_savedCreations+1] = blueprintJson
	end
	
	--Chests
	if self.chests then
		g_savedChests = {}
		for index, chest in ipairs(self.chests) do
			g_savedChests[index] = {}
			if sm.exists( chest ) then
				local container = chest:getContainer()
				for slot = 1, container:getSize() do
					local item = container:getItem( slot - 1 ) -- container is 0 indexed
					g_savedChests[index][slot] = { uuid = tostring( item.uuid ), quantity = item.quantity }
				end
			end
		end
	end

	--Notify Observer Bots
	for _,observer in pairs( self.observerBots ) do
		observer.active = true
	end
end

function ChallengeWorld.server_startChallenge( self )
	self.challengeStarted = true
	self.allowAutoSave = false
	restrictAllBodies()

	for _, buildArea in ipairs( self.buildAreas ) do
		buildArea.active = false
	end

	--Remove all lifts
	local players = sm.player.getAllPlayers()
	for _, player in ipairs( players ) do
		player:removeLift()
	end

	sm.event.sendToGame( "server_onChallengeStarted" )

	if self.tutorialStage ~= "Done" then
		self.tutorialStage = "Done"
		self.network:sendToClients( "client_onStopTutorialArrow" )
	end
end

function ChallengeWorld.trigger_onExitStart( self, trigger, results )
	if not self.challengeStarted and #self.challengeStarters == 0 then
		local foundSeat = findSteering( results )

		-- A seat left the start area
		if foundSeat ~= nil then
			self.firstSeat = foundSeat
			self:server_startChallenge()
		end
	end
end

function ChallengeWorld.trigger_onEnterGoal( self, trigger, results )

	local goalInteractable = trigger:getHostInteractable()
	
	-- Check if challenge is already complete
	if goalInteractable == nil or not sm.exists( goalInteractable ) or self.challengeCompleted or not self.challengeStarted then
		return
	end
	
	local goalParent = goalInteractable:getSingleParent()
	if goalParent then
		if not goalParent.active then
			return
		end  
	end

	local foundPlayer = false
	local foundSeat = false
	local playerName = ""

	-- Players
	local players = sm.player.getAllPlayers()

	local scanForPlayerAndSeat = function( collection )
		for _,result in ipairs( collection ) do
			if sm.exists(result) then
				if type( result ) == "Character" then 
					for i=1,#players do
						if players[i]:getCharacter().id == result.id then
							foundPlayer = true
							playerName = players[i]:getName()
							break
						end
					end
				elseif type( result ) == "Body" then
					for _, shape in ipairs( result:getShapes() ) do
						if shape then
							local interactable = shape:getInteractable()
							if interactable and interactable == self.firstSeat then
								foundSeat = true
								break
							end
						end
					end
				end
			end
		end
	end
	

	-- New players and parts in the goal
	scanForPlayerAndSeat( results )
	local victoryParams = { showWinnerName = #self.challengeStarters > 0 and #players > 1, winnerName = playerName,
							canSaveCreation = #self.chests == 1 }
	
	-- Players and parts already in the goal
	local contents = trigger:getContents()
	scanForPlayerAndSeat( contents )
	
	
	-- Complete challenge
	if foundPlayer and foundSeat then
		goalInteractable.active = true
		self.challengeCompleted = true
		
		sm.event.sendToGame( "server_onChallengeCompleted", victoryParams )
	elseif foundPlayer and #self.challengeStarters > 0 then
		goalInteractable.active = true
		self.challengeCompleted = true
		
		sm.event.sendToGame( "server_onChallengeCompleted", victoryParams )
	end
	
end

function ChallengeWorld.trigger_onEnterKillWarningBox( self, trigger, results )

	-- New objects in the kill box
	for _,result in ipairs( results ) do
		if sm.exists( result ) then
			if type( result ) == "Character" then
				self.network:sendToClients( "client_falling", result )
			end
		end
	end

end


function ChallengeWorld.trigger_onEnterKillBox( self, trigger, results )

	-- New objects in the kill box
	for _,result in ipairs( results ) do
		if sm.exists( result ) then
			-- Respawn character
			if type( result ) == "Character" then
				if result:isPlayer() then
					self:server_spawnCharacter( { players = { result:getPlayer() } } )
				else
					local unit = result:getUnit()
					if unit and sm.exists( unit ) then
						unit:destroy()
					end
				end
			end
			--Destroy shapes
			if type( result ) == "Body" then
				for i, shape in ipairs( result:getShapes() ) do
					if not self.challengeCompleted then
						if shape:getShapeUuid() == obj_interactive_driverseat then
							sm.event.sendToGame("server_onWorldFail")
						end
					end
					sm.shape.destroyShape( shape )
				end
			end
		end
	end

end

function ChallengeWorld.server_onProjectile( self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, target, projectileUuid )
	ChallengeBaseWorld.server_onProjectile( self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, target, projectileUuid )
	local EPSILON = 2.2204460492503131e-016
	local function sign( value )
		return value >= EPSILON and 1 or ( value <= -EPSILON and -1 or 0 )
	end
	
	-- Spawn loot from projectiles with loot user data
	if userData and userData.lootUid then
		local normal = -hitVelocity:normalize()
		local zSignOffset = math.min( sign( normal.z ), 0 ) * 0.5
		local offset = sm.vec3.new( 0, 0, zSignOffset )
		local lootHarvestable = sm.harvestable.createHarvestable( sm.uuid.new( "97fe0cf2-0591-4e98-9beb-9186f4fd83c8" ), hitPos + offset, sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), sm.vec3.new( 0, 0, 1 ) ) )
		lootHarvestable:setParams( { uuid = userData.lootUid, quantity = userData.lootQuantity } )
		
		-- Store it globaly so we can recreate dropped item upon reset
		local droppedItem = { tick = sm.game.getCurrentTick(), hvs = lootHarvestable, pos = hitPos + offset, uuid = userData.lootUid, quantity = userData.lootQuantity }
		table.insert( g_droppedItems, droppedItem )

	end
	
end

function ChallengeWorld.server_challengeStarted( self )
	self.network:sendToClients( "client_challengeStarted" )
end

function ChallengeWorld.server_challengeCompleted( self )
	self.network:sendToClients( "client_challengeCompleted" )
end

-- [[ Client ]]

function ChallengeWorld.client_onDestroy( self )
	if self.arrow ~= nil then
		self.arrow:stop()
		self.arrow = nil
	end
	self.audio:stop()
end

function ChallengeWorld.client_onSetTutorialArrow( self, params )

	if self.arrow ~= nil then
		self.arrow:stop()
		self.arrow = nil
	end

	if params.target ~= nil then
		self.arrow = sm.effect.createEffect( "Chest - Arrow" )
		self.arrow:start()
		self.arrowPosition = params.target.shape.worldPosition
		self.arrowTarget = params.target
	end
end

function ChallengeWorld.client_onStopTutorialArrow( self )
	if self.arrow ~= nil then
		self.arrow:stop()
		self.arrow = nil
	end
end

function ChallengeWorld.client_onFixedUpdate( self )
	self.waterManager:cl_onFixedUpdate()
end

function ChallengeWorld.client_onUpdate( self, dt )
	g_effectManager:cl_onWorldUpdate( self )

	if self.arrow ~= nil then
		if self.arrowTarget and sm.exists( self.arrowTarget ) then
			self.arrowPosition = sm.vec3.lerp( self.arrowPosition, self.arrowTarget.shape.worldPosition, 10.0 * dt )
			self.arrow:setPosition( self.arrowPosition + sm.vec3.new( 0.0, 0.0, 4.0 ) )
		else
			self.arrow:stop()
			self.arrow = nil
		end
	end
end

function ChallengeWorld.client_onCellLoaded( self, x, y )
	self.waterManager:cl_onCellLoaded( x, y )
	g_effectManager:cl_onWorldCellLoaded( self, x, y )
end

function ChallengeWorld.client_onCellUnloaded( self, x, y )
	self.waterManager:cl_onCellUnloaded( x, y )
	g_effectManager:cl_onWorldCellUnloaded( self, x, y )
end

function ChallengeWorld.client_falling( self, character )
	if character == sm.localPlayer.getPlayer().character then
		print( "Player fall" )
		sm.audio.play( "Challenge - Fall" )
	end
end

function ChallengeWorld.client_spawned( self, params )
	if params.player == sm.localPlayer.getPlayer() then
		sm.effect.playEffect( "Supervisor - Fail", self.audioPosition )
		if g_effectManager and params.playCutscene then
			g_effectManager:cl_playNamedCinematic( "LevelIntro" )
		end
	end
end

function ChallengeWorld.client_challengeStarted( self )
	if self.startedEffectTriggered then
		return
	end
	
	self.startedEffectTriggered = true
	
	sm.audio.play( "Challenge - Start" )
end

function ChallengeWorld.client_challengeCompleted( self )
	if self.completedEffectTriggered then
		return
	end

	self.completedEffectTriggered = true
	
	sm.effect.playEffect( "Supervisor - Cheer", self.audioPosition )
end
