dofile( "$CONTENT_DATA/Scripts/ChallengeModeScripts/challenge/game_util.lua" )
dofile( "$CONTENT_DATA/Scripts/ChallengeModeScripts/challenge/world_util.lua" )
dofile( "$CONTENT_DATA/Scripts/ChallengeModeScripts/game/challenge_shapes.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_meleeattacks.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/EffectManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/managers/UnitManager.lua" )

ChallengeGame = class( nil )
ChallengeGame.enableLimitedInventory = true
ChallengeGame.enableRestrictions = true
ChallengeGame.enableAmmoConsumption = false
ChallengeGame.enableFuelConsumption = false
ChallengeGame.enableUpgrade = true

function ChallengeGame.server_onCreate( self )
	print( "ChallengeGame.server_onCreate" )
	g_disableScrapHarvest = true

	g_unitManager = UnitManager()
	g_unitManager:sv_onCreate()

	if self.data.startLevelIndex ~= nil then
		-- Play mode
		self.play = {}
		self.play.currentLevelIndex = self.data.startLevelIndex
		self.play.levelList = self.data.levelList
		for _,level in ipairs( self.play.levelList ) do
			resolveContentPaths( level.data )
			level.data.tiles[#level.data.tiles + 1] = "$CONTENT_DATA/Terrain/Tiles/challengemode_env_DT.tile"
		end
	else
		-- Build mode
		self.build = {}
		self.build.testing = false
		self.build.level = {}
		self.build.level.uuid = self.data.uuid
		self.build.level.data = self.data.data
		resolveContentPaths( self.build.level.data )
		self.build.level.data.tiles[#self.build.level.data.tiles + 1] = "$CONTENT_DATA/Terrain/Tiles/challengebuilder_env_DT.tile"

		sm.game.setLimitedInventory( false )
		g_inventoriesBuildMode = {}

		sm.game.bindChatCommand( "/save", {}, "server_onChatCommand", "Save the challenge" )
		sm.game.bindChatCommand( "/test", {}, "server_onChatCommand", "Test the challenge" )
		sm.game.bindChatCommand( "/stop", {}, "server_onChatCommand", "Stop the test" )
	end

	--self.data = nil

	self:server_start()
	self.isNewLevel = true
	if self.build then
		-- Save for going back to build mode
		self.build.buildWorld = self.world
		self.build.saveReminderTick = sm.game.getCurrentTick()
	end
end

function ChallengeGame.server_onRefresh( self )
	print( "ChallengeGame.server_onRefresh" )
end

function ChallengeGame.server_onFixedUpdate( self )
	if self.build then
		if sm.game.getCurrentTick() - self.build.saveReminderTick > ( 20 * 2400 ) and self.build.testing == false then
			self.build.saveReminderTick = sm.game.getCurrentTick()
			sm.gui.chatMessage( "#{CHALLENGE_BUILDER_SAVE_REMINDER}" )
		end
	end
	g_unitManager:sv_onFixedUpdate()
end

function ChallengeGame.server_startTest( self, levelData )
	print( "Testing challenge" )

	--Save hotbar configuration and clear creative inventory tools before setting limited inventory
	g_inventoriesBuildMode = {}
	for i, player in ipairs( sm.player.getAllPlayers() ) do
		local inventoryList = {}
		local inventoryContainer = player:getHotbar()
		sm.container.beginTransaction()
		for i = 1, inventoryContainer:getSize() do
			local item = inventoryContainer:getItem( i - 1 ) -- container is 0 indexed
			inventoryList[i] = { uuid = item.uuid, quantity = item.quantity, instance = item.instance }
			sm.container.setItem( inventoryContainer, i - 1, sm.uuid.getNil(), 0 ) -- container is 0 indexed
		end
		sm.container.endTransaction()
		g_inventoriesBuildMode[player.id] = inventoryList
	end
	
	sm.game.setLimitedInventory( true )
	
	self.build.testing = true
	self.build.level.data = levelData
	resolveContentPaths( self.build.level.data )
	self.build.level.data.tiles[#self.build.level.data.tiles + 1] = "$CONTENT_DATA/Terrain/Tiles/challengemode_env_DT.tile"

	-- Prevent build mode world destroy
	self.world = nil
	self:server_start()
end

function ChallengeGame.server_stopTest( self )
	if not self.build.testing then
		print( "Ignoring multiple stop test calls" )
		return
	end
	print( "Going back to build world" )
	
	self.server_challengeStarted = false
	self.server_challengeCompleted = false
	self.network:sendToClients( "client_onChallengeReset" )
	
	sm.game.setLimitedInventory( false )
	sm.game.setEnableAmmoConsumption( self.enableAmmoConsumption )
	sm.game.setEnableFuelConsumption( self.enableFuelConsumption )
	
	self.world:destroy()

	self.world = self.build.buildWorld
	self.activeWorld = self.world

	self.build.testing = false

	self:server_onChallengeReset()

	sm.event.sendToWorld( self.activeWorld, "server_spawnCharacter", { players = sm.player.getAllPlayers() } )
end

function ChallengeGame.server_start( self )
	print("SERVER START")
	g_savedCreations = {}
	g_inventoriesPlayMode = {}
	g_savedChests = {}
	g_tutorial = false
	g_droppedItems = {}
	
	self.server_challengeStarted = false
	self.server_challengeCompleted = false
	self.server_completionTime = 0.0
	self.server_sessionID = 0

	sm.challenge.stop()
	
	self:server_loadLevel( true, self.play ~= nil )
	self.activeWorld = nil
end

function ChallengeGame.server_onPlayerJoined( self, player )
	print( "Hello "..player.name )

	--Create character if world is ready
	if self.activeWorld then
		

		--sm.event.sendToWorld( self.activeWorld, "server_spawnNewCharacter", { players = { player } } )
		self.activeWorld:loadCell( 0, 0, player, "sv_createPlayerCharacter" )
		
		self.network:sendToClients( "client_sessionStarted", { sessionID = self.server_sessionID } )
		if self.server_challengeCompleted then
			sm.event.sendToWorld( self.activeWorld, "server_challengeCompleted" )
			self.network:sendToClients( "client_onChallengeCompleted",
				{ time = self.server_completionTime, finalLevel = isFinalLevel( self.play ) } )
		elseif self.server_challengeStarted then
			sm.event.sendToWorld( self.activeWorld, "server_challengeStarted" )
			self.network:sendToClients( "client_onChallengeStarted",
				{ ticksSinceStart = sm.game.getCurrentTick() - self.timerStartTick } )
		end
	end

	g_unitManager:sv_onPlayerJoined( player )
end

function ChallengeGame.server_getLevelData( self )
	if self.build then
		return self.build.level.data
	else
		return self.play.levelList[self.play.currentLevelIndex].data
	end
end

function ChallengeGame.server_getLevelUuid( self )
	if self.build then
		return sm.uuid.new( self.build.level.uuid )
	else
		return sm.uuid.new( self.play.levelList[self.play.currentLevelIndex].uuid )
	end
end

-- Main Menu callbacks

function ChallengeGame.server_onReset( self )
	if self.loadingLevelFlag then 
		return
	end

	self:server_resetLevel()
end

function ChallengeGame.server_onRestart( self )
	if self.loadingLevelFlag then 
		return
	end

	self:server_restartLevel()
end

function ChallengeGame.server_onSaveLevel( self )
	if self.activeWorld and self.build then
		sm.event.sendToWorld( self.activeWorld, "server_export" )
		
		self.build.saveReminderTick = sm.game.getCurrentTick()
	end
end

function ChallengeGame.server_onTestLevel( self )
	if self.activeWorld and self.build and not self.build.testing then
		sm.event.sendToWorld( self.activeWorld, "server_test" )
	end
end

function ChallengeGame.server_onStopTest( self )
	if self.activeWorld and self.build and self.build.testing then
		self:server_stopTest()
		
		self.build.saveReminderTick = sm.game.getCurrentTick()
	end
end

-- GUI callbacks

function ChallengeGame.server_onResetPressed( self, params )
	if self.server_sessionID ~= params.sessionID or self.loadingLevelFlag then 
		return
	end

	self:server_resetLevel()
end

function ChallengeGame.server_onNextPressed( self, params )
	if not self.server_challengeCompleted or self.server_sessionID ~= params.sessionID or self.loadingLevelFlag then 
		return
	end

	self:server_nextLevel()
end

function ChallengeGame.server_onFinishPressed( self, params )
	if not self.server_challengeCompleted or self.server_sessionID ~= params.sessionID or self.loadingLevelFlag or not self.finalLevel then
		return
	end

	self:sv_loadVictoryLevel()
end

-- Chat commands

function ChallengeGame.server_onChatCommand( self, params )
	if params[1] == "/save" then
		if self.activeWorld and self.build then
			sm.event.sendToWorld( self.activeWorld, "server_export" )
		end
	elseif params[1] == "/test" then
		if self.activeWorld and self.build and not self.build.testing then
			sm.event.sendToWorld( self.activeWorld, "server_test" )
		end
	elseif params[1] == "/stop" then
		if self.activeWorld and self.build and self.build.testing then
			self:server_stopTest()
		end
	end
end

-- World callbacks

function ChallengeGame.server_onWorldFail( self )
	if self.loadingLevelFlag then 
		return
	end

	self:server_resetLevel()
end


-- Reset / Restart / Next - Level

function ChallengeGame.server_resetLevel( self )
	print( "RESET" )
	self:server_onChallengeReset()
	self:server_loadLevel( false, false )
end

function ChallengeGame.server_restartLevel( self )
	print( "RESTART" )
	self:server_onChallengeReset()
	self:server_loadLevel( true, false )
end

function ChallengeGame.server_nextLevel( self )
	print( "NEXT LEVEL" )
	self:server_onChallengeReset()

	if self.play.currentLevelIndex < #self.play.levelList then
		print( "Time to change level! (from "..self.play.currentLevelIndex.." to "..( self.play.currentLevelIndex + 1 )..")" )
		self.play.currentLevelIndex = self.play.currentLevelIndex + 1
		self.isNewLevel = true
		self:server_loadLevel( true, true )
	else
		print( "Final level completed!" )
	end
end

-- Load Level

function ChallengeGame.sv_loadVictoryLevel( self )
	self:server_onChallengeReset()

	self.loadingLevelFlag = true

	if self.world then
		self.world:destroy()
		self.world = nil
	end

	local worldData = {}
	worldData.tiles = {}
	worldData.tiles[#worldData.tiles+1] = "$CONTENT_DATA/Terrain/Challangemode_victoryscene.tile"
	self.world = sm.world.createWorld( "$CONTENT_DATA/Scripts/challenge/ChallengeVictoryWorld.lua", "ChallengeVictoryWorld", worldData )
end

function ChallengeGame.server_loadLevel( self, loadJsonData, loadSaveData )
	print( "Loading level: "..tostring( self:server_getLevelUuid() ) )
	
	self.loadingLevelFlag = true

	-- Load game settings
	if self.build == nil or self.build.testing then
		local levelData = self:server_getLevelData()
		local enableAmmoConsumption = getSettingValue( levelData.settings, "enable_ammo_consumption")
		sm.game.setEnableAmmoConsumption( enableAmmoConsumption == nil and self.enableAmmoConsumption or enableAmmoConsumption )
		local enableFuelConsumption = getSettingValue( levelData.settings, "enable_fuel_consumption" )
		sm.game.setEnableFuelConsumption( enableFuelConsumption == nil and self.enableFuelConsumption or enableFuelConsumption )
	end

	-- Saved data from level json
	if loadJsonData then
		self:server_loadJsonData()
	end

	-- Saved data from completed level
	if loadSaveData then
		self:server_loadSaveData()
	end
	
	if self.world then
		self.world:destroy()
		self.world = nil
	end
	
	local worldScriptFilename
	local worldScriptClass

	if self.build and not self.build.testing then
		worldScriptFilename = "$CONTENT_DATA/Scripts/ChallengeModeScripts/challenge/BuilderWorld.lua"
		worldScriptClass = "BuilderWorld"
	else
		worldScriptFilename = "$CONTENT_DATA/Scripts/ChallengeModeScripts/challenge/ChallengeWorld.lua"
		worldScriptClass = "ChallengeWorld"
	end

	self.world = sm.world.createWorld( worldScriptFilename, worldScriptClass, self:server_getLevelData() )

	local players = sm.player.getAllPlayers()
	local x = 0
	local y = 0
	--for x = -32, 32 do
	--	for y = -32, 32 do
	for _,player in pairs(players) do
		self.world:loadCell( x, y, player)
	end
	--end
	--end
end

function ChallengeGame.server_loadJsonData( self )
	local levelData = self:server_getLevelData()

	g_savedCreations = {}
	-- Starting creations
	if levelData.startCreations then
		for _,creation in ipairs( levelData.startCreations ) do
			local blueprintObject = sm.json.open( creation )
			local blueprintJson = sm.json.writeJsonString( blueprintObject )
			g_savedCreations[#g_savedCreations+1] = blueprintJson
		end
	end
	
	-- Starting inventory
	g_inventoriesPlayMode = {}

	-- Chest contents
	g_savedChests = {}
	if levelData.chestContents then
		g_savedChests[1] = {}
		g_savedChests[1] = levelData.chestContents
	end
	
	g_tutorial = levelData.tutorial
	g_droppedItems = {} 
end


function ChallengeGame.server_loadSaveData( self )
	local levelData = self:server_getLevelData()
	local saveData = sm.challenge.getSaveData( self:server_getLevelUuid() )
	
	if saveData and saveData.creations then
		g_savedCreations = saveData.creations

		local usedShapes = {}
		
		-- Count the saved creation's content
		if saveData.creations then
			local savedCreations = {}
			for _, creation in ipairs( saveData.creations ) do
				savedCreations[#savedCreations+1] = sm.json.parseJsonString( creation )
			end
			usedShapes = getCreationsShapeCount( savedCreations )
		end

		local availableShapes = {}
		
		-- Count the starting creations' content
		if levelData.startCreations then
			local startCreations = {}
			for _, creation in ipairs( levelData.startCreations ) do
				startCreations[#startCreations+1] = sm.json.open( creation )
			end
			availableShapes = getCreationsShapeCount( startCreations )
		end
		
		-- Count the starting chest content
		if levelData.chestContents then
			for _, slot in ipairs( levelData.chestContents ) do
				if availableShapes[slot.uuid] == nil then
					availableShapes[slot.uuid] = 0
				end
				availableShapes[slot.uuid] = availableShapes[slot.uuid] + slot.quantity
			end
		end
		
		-- Remove used shapes from available shapes
		for shape in pairs( availableShapes ) do
			if usedShapes[shape] ~= nil then
				availableShapes[shape] = availableShapes[shape] - usedShapes[shape]
			end
		end
		
		-- Store the remaining shapes in the starting chest
		g_savedChests = {}
		g_savedChests[1] = {}
		local index = 1
		for shape in pairs( availableShapes ) do
			if availableShapes[shape] > 0 then
				g_savedChests[1][index] = { uuid = shape, quantity = availableShapes[shape] }
				index = index + 1
			end
		end
	end
end


function ChallengeGame.server_onCellLoadComplete( self, data )
	--if self.activeWorld ~= data.world then
	self.activeWorld = data.world
	--local players = sm.player.getAllPlayers()
	--sm.event.sendToWorld( self.activeWorld, "server_spawnCharacter", { players = players, playCutscene = self.isNewLevel } )
	--sm.event.sendToWorld( self.activeWorld, "server_loadWorldContent" )
	self.isNewLevel = false
	--else
	self.loadingLevelFlag = false
	--end
	
	self.server_sessionID = self.server_sessionID + 1

	self.network:sendToClients( "client_sessionStarted", { sessionID = self.server_sessionID } )
end

function ChallengeGame.server_onFinishedLoadContent( self )
	self.loadingLevelFlag = false
end

-- World Challenge callbacks

function ChallengeGame.server_onChallengeStarted( self )
	self.server_challengeStarted = true
	self.server_challengeCompleted = false

	self.challengeStartTick = sm.game.getCurrentTick()
	sm.challenge.start( self.activeWorld )
	
	sm.event.sendToWorld( self.activeWorld, "server_challengeStarted" )
	self.network:sendToClients( "client_onChallengeStarted", { ticksSinceStart = 0 } )
end

function ChallengeGame.server_onChallengeCompleted( self, victoryParams )
	self.server_challengeStarted = true
	self.server_challengeCompleted = true

	local tickDuration = sm.game.getCurrentTick() - self.challengeStartTick
	self.server_completionTime = tickDuration * ( 1.0 / 40.0 )

	sm.challenge.stop()
	local saveData = {}
	if self.play and victoryParams.canSaveCreation == true then
		saveData = { creations = g_savedCreations }
	end
	local prevCompletionTime = sm.challenge.getCompletionTime( self:server_getLevelUuid() )
	local newRecord = self.server_completionTime < prevCompletionTime or prevCompletionTime == 0.0

	sm.challenge.levelCompleted( self:server_getLevelUuid(), self.server_completionTime, saveData )

	sm.event.sendToWorld( self.activeWorld, "server_challengeCompleted" )
	if victoryParams.showWinnerName == true then
		self.network:sendToClients( "client_onChallengeCompleted",
			{ time = self.server_completionTime, finalLevel = isFinalLevel( self.play ), winnerName = victoryParams.winnerName, newRecord = newRecord } )
	else
		self.network:sendToClients( "client_onChallengeCompleted",
			{ time = self.server_completionTime, finalLevel = isFinalLevel( self.play ), newRecord = newRecord } )
	end
		
end

function ChallengeGame.server_onChallengeReset( self )
	sm.challenge.stop()
	self.server_challengeStarted = false
	self.server_challengeCompleted = false
	self.server_completionTime = 0.0
	for _, player in ipairs( sm.player.getAllPlayers() ) do
		sm.event.sendToPlayer( player, "sv_e_challengeReset" )
	end
	self.network:sendToClients( "client_onChallengeReset" )
end

function ChallengeGame.sv_e_respawn( self, params )
	if self.activeWorld and sm.exists( self.activeWorld ) then
		sm.event.sendToWorld( self.activeWorld, "server_spawnCharacter", { players = { params.player } } )
	else
		sm.log.warning( "ChallengeGame.sv_e_respawn with no active world" )
	end
end

-- Game Client side --

function ChallengeGame.client_onCreate( self )
	print("ChallengeGame.client_onCreate")

	sm.localPlayer.setLockedControls( false )

	g_effectManager = EffectManager()
	g_effectManager:cl_onCreate()

	self.timerState = "off"
	self.timerBlink = 0.0
	self.completionTimeString = "00:00:00"

	self.messageGuiTimer = 0.0

	self.challengeStarted = false
	self.challengeCompleted = false

	self.hasShownWelcomeMessage = false

	if self.data and self.data.startLevelIndex == nil then
		self.build = {}
	end

	self:setupHUD()
	self:setupMessageGui()

	if self.build and self.hasShownWelcomeMessage == false then
		self.cl_pendingShownWelcomeMessageFlag = true
	end

	if g_unitManager == nil then
		assert( not sm.isHost )
		g_unitManager = UnitManager()
	end
	g_unitManager:cl_onCreate()

	-- Survival HUD, for HP (TODO: challengeHUD)
	g_survivalHud = sm.gui.createSurvivalHudGui()
	--assert(g_survivalHud)
	g_survivalHud:setVisible( "FoodBar", false )
	g_survivalHud:setVisible( "WaterBar", false )
end

function ChallengeGame.client_onDestroy( self )
	if self.HUD ~= nil then
		self.HUD:destroy()
		self.HUD = nil
	end
	if self.messageGui ~= nil then
		self.messageGui:destroy()
		self.messageGui = nil
	end
end

function ChallengeGame.client_onUpdate( self, dt )
	if self.HUD ~= nil then
		if self.timerState ~= "off" then
			local displayTime = "00:00:00"

			if self.timerState == "running" then

				local passedTime  = (sm.game.getCurrentTick() - self.timerStartTick) * ( 1.0 / 40.0 )
				local milliseconds = passedTime % 1.0
				local seconds = ( passedTime - milliseconds ) % 60.0
				local minutes = ( passedTime - ( seconds + milliseconds ) ) / 60
				displayTime = string.format( "%02i:%02i:%03i", minutes, seconds, milliseconds * 1000 )

				if not self.HUDTimeVisible then
					self.HUDTimeVisible = true
					self.HUD:setVisible( "Time", self.HUDTimeVisible )
				end

			elseif self.timerState == "ended" then
				displayTime = self.completionTimeString

				self.timerBlink = self.timerBlink + dt
				if self.timerBlink > 0.45 then
					if self.HUDTimeVisible then
						self.HUDTimeVisible = false
					else
						self.HUDTimeVisible = true
					end
					self.HUD:setVisible( "Time", self.HUDTimeVisible )
					self.timerBlink = 0.0
				end

			end
			
			self.HUD:setText( "Time", displayTime )
		elseif self.HUDTimeVisible then
			self.HUDTimeVisible = false
			self.HUD:setVisible( "Time", self.HUDTimeVisible )
		end

		if self.messageGuiTimer > 0.0 then
			self.messageGuiTimer = self.messageGuiTimer - dt
			if self.messageGuiTimer <= 0.0 then
				if not self.messageGui:isActive() then
					sm.gui.hideGui( false )
					self.messageGui:open()
				end
				self.messageGuiTimer = 0.0
				self.timerState = "off"
			end
		end
	end

	if self.build and self.hasShownWelcomeMessage == false and self.cl_pendingShownWelcomeMessageFlag == true then
		self.cl_pendingShownWelcomeMessageFlag = false
		sm.gui.chatMessage( "#7eddde#{CHALLENGE_BUILDER_CHAT_MESSAGE}" )
		self.hasShownWelcomeMessage = true
	end
end

function ChallengeGame.client_onLoadingScreenLifted( self )
	g_effectManager:cl_onLoadingScreenLifted()
end

-- GUI Setup

function ChallengeGame.setupMessageGui( self )
	-- print( "ChallengeGame.setupMessageGui" )

	self.messageGui = sm.gui.createChallengeMessageGui()
	
	self.messageGui:setButtonCallback( "Reset", "client_onResetPressed" )
	self.messageGui:setButtonCallback( "Next", "client_onNextPressed" )
	
	self.messageGuiTimer = 0.0
	if self.messageGui:isActive() then
		self.messageGui:close()
	end
end

function ChallengeGame.setupHUD( self )
	-- print( "ChallengeGame.setupHUD" )
	
	self.HUD = sm.gui.createChallengeHUDGui()
	self.HUD:setText("Time", "00:00:00")
	self.HUDTimeVisible = false
	self.HUD:setVisible( "Time", self.HUDTimeVisible )
	self.HUD:open();
end

function ChallengeGame.client_showMessage( self, params )
	self.messageGui:setText( "Title", params.title )
	if params.winnerName then
		self.messageGui:setText( "Message", params.winnerName .. ": " .. params.message )
	else
		self.messageGui:setText( "Message", params.message )
	end

	if params.newRecord == true then
		self.messageGui:setText( "SubTitle", "#{CHALLENGE_NEW_RECORD}" )
	else
		self.messageGui:setText( "SubTitle", "#{TIME}" )
	end
	
	self.messageGuiTimer = params.delay or 0.0
	if self.messageGuiTimer == 0.0 then
		if not self.messageGui:isActive() then
			sm.gui.hideGui( false )
			self.messageGui:open()
		end
		self.timerState = "off"
	else
		if self.messageGui:isActive() then
			self.messageGui:close()
		end
	end
	
	
	if params.finalLevel == false then
		self.messageGui:setText( "Next", "#{CHALLENGE_NEXT}" );
	else
		self.messageGui:setText( "Next", "#{CHALLENGE_FINISH}" );
	end
end

-- GUI button callbacks

function ChallengeGame.client_onNextPressed( self )
	if self.messageGui:isActive() then
		self.messageGui:close()
	end

	if self.finalLevel == true then
		if self.build then
			self.network:sendToServer( "server_stopTest" )
		else
			if sm.challenge.isMasterMechanicTrial() then
				self.network:sendToServer( "server_onFinishPressed", { sessionID = self.client_sessionID } )
			else
				sm.gui.exitToMenu()
			end
		end
	else
		self.network:sendToServer( "server_onNextPressed", { sessionID = self.client_sessionID } )
	end
end

function ChallengeGame.client_onResetPressed( self )
	if self.messageGui:isActive() then
		self.messageGui:close()
	end
	
	self.network:sendToServer( "server_onResetPressed", { sessionID = self.client_sessionID } )
end

-- Challange state callbacks

function ChallengeGame.client_onChallengeReset( self )

	self.challengeStarted = false
	self.challengeCompleted = false

	self.HUD:setText( "Time", "00:00:00" )

	self.HUDTimeVisible = false
	self.HUD:setVisible( "Time", self.HUDTimeVisible )
	self.HUD:open()

	self.timerState = "off"
	self.timerBlink = 0.0

	self.messageGuiTimer = 0.0
	if self.messageGui:isActive() then
		self.messageGui:close()
	end
	self.completionTimeString = "00:00:00"
end

function ChallengeGame.client_onChallengeStarted( self, params )
	if self.challengeStarted then
		return
	end

	self.challengeStarted = true
	self.challengeCompleted = false

	self.completionTimeString = "00:00:00"
	self.timerState = "running"
	self.timerStartTick = sm.game.getCurrentTick() - params.ticksSinceStart
	if sm.isHost then
		g_showMasterMechanicTrialsReward = not sm.localPlayer.isGarmentUnlocked( sm.uuid.new( "420ea3ba-f09b-44ce-9e4c-7040ef057a0c" ) ) -- Check for stuntman torso
	end
end

function ChallengeGame.client_onChallengeCompleted( self, params )
	if self.challengeCompleted then
		return
	end

	self.challengeStarted = true
	self.challengeCompleted = true

	local completionTime = params.time
	self.timerState = "ended"
	
	local milliseconds = completionTime % 1.0
	local seconds = ( completionTime - milliseconds ) % 60.0
	local minutes = ( completionTime - ( seconds + milliseconds ) ) / 60
	local timeString = string.format("%02i:%02i:%03i", minutes, seconds, milliseconds * 1000 )
	self.completionTimeString = timeString
	self.finalLevel = params.finalLevel

	self:client_showMessage( { delay = 3.5, title = "#{CHALLENGE_WIN}", message = timeString, finalLevel = params.finalLevel, winnerName = params.winnerName, newRecord = params.newRecord } )
end

function ChallengeGame.client_sessionStarted( self, params )
	self.client_sessionID = params.sessionID
end

function ChallengeGame.cl_e_leaveGame( self )
	sm.gui.exitToMenu()
end