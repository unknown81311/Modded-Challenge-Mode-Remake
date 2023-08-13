dofile( "$CONTENT_DATA/Scripts/ChallengeModeScripts/challenge/ChallengeBaseWorld.lua")
dofile( "$CONTENT_DATA/Scripts/ChallengeModeScripts/challenge/world_util.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/util/Timer.lua" )

ChallengeVictoryWorld = class( ChallengeBaseWorld )
ChallengeVictoryWorld.terrainScript = "$CONTENT_DATA/Scripts/challenge/terrain_challenge.lua"
ChallengeVictoryWorld.enableSurface = false
ChallengeVictoryWorld.enableAssets = true
ChallengeVictoryWorld.enableClutter = false
ChallengeVictoryWorld.enableNodes = true
ChallengeVictoryWorld.enableCreations = true
ChallengeVictoryWorld.enableHarvestables = false
ChallengeVictoryWorld.enableKinematics = false
ChallengeVictoryWorld.cellMinX = 0
ChallengeVictoryWorld.cellMaxX = 0
ChallengeVictoryWorld.cellMinY = 0
ChallengeVictoryWorld.cellMaxY = 0

local HostSpawnPosition = sm.vec3.new( -0.012, 0.073, 23.19 )
local ApprovedTickTime = 2.7 * 40

function ChallengeVictoryWorld.server_onCreate( self )
	ChallengeBaseWorld.server_onCreate( self )
	self.sv = self.sv or {}
end

function ChallengeVictoryWorld.server_onFixedUpdate( self )
	ChallengeBaseWorld.server_onFixedUpdate( self )
end

function ChallengeVictoryWorld.server_onCellCreated( self, x, y )
	local filter = sm.areaTrigger.filter.character + sm.areaTrigger.filter.dynamicBody
	local halfSize = sm.vec3.new( 64, 64, 64 )
	self.sv.playAreaTrigger = sm.areaTrigger.createBox( halfSize, HostSpawnPosition, sm.quat.identity(), filter )
	self.sv.playAreaTrigger:bindOnExit( "trigger_onExitPlayArea" )

	sm.event.sendToGame( "server_onCellLoadComplete", { world = self.world, x = x, y = y } )
end

-- (Event) Called from Game
function ChallengeVictoryWorld.server_spawnNewCharacter( self, params )
	-- New player joined
	self:server_spawnCharacter( params )
end

-- (Event) Called from Game
function ChallengeVictoryWorld.server_spawnCharacter( self, params )
	-- Create a victory character
	local yaw = 0
	local pitch = 0
	local clientSpawnPositions = {
		HostSpawnPosition + sm.vec3.new( -1.0, -1.0, 0.0 ),
		HostSpawnPosition + sm.vec3.new( 1.0, -1.0, 0.0 ),
		HostSpawnPosition + sm.vec3.new( -1.5, 0.5, 0.0 ),
		HostSpawnPosition + sm.vec3.new( 1.5, 0.5, 0.0 ) }

	for _, player in ipairs( params.players ) do
		local spawnPosition = HostSpawnPosition
		if player.id > 1 then
			local positionIndex = ( ( player.id - 2 ) % #clientSpawnPositions ) + 1
			spawnPosition = clientSpawnPositions[positionIndex]
		end
		local character = sm.character.createCharacter( player, self.world, spawnPosition, yaw, pitch )
		player:setCharacter( character )
		self.network:sendToClient( player, "cl_n_spawned" )
	end
end

-- (Event) Called from Game
function ChallengeVictoryWorld.server_loadWorldContent( self, data )
	local players = sm.player.getAllPlayers()
	for _, player in ipairs( players ) do
		self:sv_loadInventory( player )
	end

	sm.event.sendToGame( "server_onFinishedLoadContent" )
end

function ChallengeVictoryWorld.sv_loadInventory( self, player )
	-- Clear inventory
	local inventoryContainer = player:getInventory()
	sm.container.beginTransaction()
	for i = 0, inventoryContainer:getSize() - 1 do
		sm.container.setItem( inventoryContainer, i, sm.uuid.getNil(), 0 )
	end
	sm.container.endTransaction()

	-- Clear carry
	local carryContainer = player:getCarry()
	sm.container.beginTransaction()
	for i = 0, carryContainer:getSize() - 1 do
		sm.container.setItem( carryContainer, i, sm.uuid.getNil(), 0 )
	end
	sm.container.endTransaction()
end

function ChallengeVictoryWorld.sv_n_cinematicEvent( self, params, player )
	if params.eventName == "challengemodecomplete.celebrate" then
		player:sendCharacterEvent( "dramatics_victory_loop" )
	end
end

-- (Event) Called from Game
--function ChallengeVictoryWorld.server_challengeStarted( self ) end

-- (Event) Called from Game
--function ChallengeVictoryWorld.server_challengeCompleted( self ) end

function ChallengeVictoryWorld.trigger_onExitPlayArea( self, trigger, results )
	-- Object left the play area
	for _, result in ipairs( results ) do
		if sm.exists( result ) then
			-- Respawn character
			if type( result ) == "Character" then
				if result:isPlayer() then
					self:server_spawnCharacter( { result:getPlayer() } )
				else
					local unit = result:getUnit()
					if unit and sm.exists( unit ) then
						unit:destroy()
					end
				end
			end
			--Destroy shapes
			if type( result ) == "Body" then
				for _, shape in ipairs( result:getShapes() ) do
					sm.shape.destroyShape( shape )
				end
			end
		end
	end
end

-- [[ Client ]]

function ChallengeVictoryWorld.client_onCreate( self )
	ChallengeBaseWorld.client_onCreate( self )
	self.cl = self.cl or {}
	self.cl.watchedCutscene = false
	self.cl.cutsceneHasFinished = false

	self.cl.approvedGui = sm.gui.createGuiFromLayout( "$CONTENT_DATA/Gui/Layouts/Banner_Approved.layout", false, { isHud = true, isInteractive = false, needsCursor = false, hidesHotbar = true } )
	self.cl.approvedTimer = Timer()
	self.cl.approvedTimer:start( ApprovedTickTime )

	self.cl.stuntmanGui = sm.gui.createGuiFromLayout( "$CONTENT_DATA/Gui/Layouts/Stuntman_Unlocked.layout", false, { backgroundAlpha = 0.6 } )
	self.cl.stuntmanGui:setOnCloseCallback( "cl_onCloseStuntman" )
	self.cl.stuntmanGui:setButtonCallback( "CollectButton", "cl_onCollectPressed" )
	self.cl.closedStuntmanGui = not g_showMasterMechanicTrialsReward

	self.cl.finishGui = sm.gui.createGuiFromLayout( "$CONTENT_DATA/Gui/Layouts/Victory_Finish.layout" )
	self.cl.finishGui:setButtonCallback( "FinishButton", "cl_onFinishPressed" )
	self.cl.finishGui:setOnCloseCallback( "cl_onCloseFinish" )
	self.cl.closedFinishGui = false

	self.cl.cinematicAudioEffect = sm.effect.createEffect2D( "Cinematic - Challengemodecomplete_audio" )

	if g_survivalHud then
		g_survivalHud:close()
	end
end

function ChallengeVictoryWorld.client_onDestroy( self )
	if self.cl.approvedGui then
		self.cl.approvedGui:destroy()
	end
	if self.cl.stuntmanGui then
		self.cl.stuntmanGui:destroy()
	end
	if self.cl.finishGui then
		self.cl.finishGui:destroy()
	end
end


function ChallengeVictoryWorld.client_onUpdate( self, dt )
	g_effectManager:cl_onWorldUpdate( self )

	local cutscene = g_effectManager:cl_getWorldNamedEffect( self, "cinematic.challengemodecomplete" )
	if cutscene then
		self.cl.watchedCutscene = self.cl.watchedCutscene or cutscene.effect:isPlaying()
		self.cl.cutsceneHasFinished = self.cl.watchedCutscene and not cutscene.effect:isPlaying()
	end

	-- Custom camera
	local player = sm.localPlayer.getPlayer()
	local customCameraData
	customCameraData = {}
	customCameraData.hideGui = false
	if self.cl.cameraNode then
		customCameraData.cameraPosition = self.cl.cameraNode.position
		customCameraData.cameraRotation = self.cl.cameraNode.rotation
	end
	customCameraData.cameraState = sm.camera.state.cutsceneTP
	customCameraData.lockedControls = true
	player.clientPublicData = player.clientPublicData or {}
	player.clientPublicData.customCameraData = customCameraData
end

function ChallengeVictoryWorld.client_onFixedUpdate( self, dt )
	if self.cl.cutsceneHasFinished then
		if not self.cl.approvedTimer:done() and self.cl.approvedGui:isActive() then
			self.cl.approvedTimer:tick()
		end
		local shouldDisplayApprovedGui = not self.cl.approvedGui:isActive()
		local shouldDisplayStuntmanGui = self.cl.approvedGui:isActive() and self.cl.approvedTimer:done() and not self.cl.stuntmanGui:isActive() and not self.cl.closedStuntmanGui
		local shouldDisplayFinishGui = self.cl.approvedGui:isActive() and self.cl.approvedTimer:done() and self.cl.closedStuntmanGui and not self.cl.finishGui:isActive() and not self.cl.closedFinishGui
		if shouldDisplayApprovedGui then
			self.cl.approvedGui:open()
			self.cl.approvedGui:playEffect( "VictoryBanner", "Gui - Challengemode Approvedbannershine", true )
		elseif shouldDisplayStuntmanGui then
			self.cl.stuntmanGui:open()
			self.cl.stuntmanGui:playEffect( "UnlockBack", "Gui - Challengemode Stuntmanbackgroundshine", true )
		elseif shouldDisplayFinishGui then
			self.cl.finishGui:open()
		end
	end
end

function ChallengeVictoryWorld.client_onCellLoaded( self, x, y )
	g_effectManager:cl_onWorldCellLoaded( self, x, y )
	local cameraNodes = sm.cell.getNodesByTag( x, y, "CAMERA" )
	if cameraNodes then
		self.cl.cameraNode = cameraNodes[1]
	end
end

function ChallengeVictoryWorld.client_onCellUnloaded( self, x, y )
	g_effectManager:cl_onWorldCellUnloaded( self, x, y )
end

function ChallengeVictoryWorld.cl_n_spawned( self )
	if self.cl.watchedCutscene then
		-- Respawn in victory pose
		self.network:sendToServer("sv_n_cinematicEvent", { eventName = "challengemodecomplete.celebrate" } )
	else
		local callbacks = {}
		callbacks[#callbacks + 1] = { fn = "cl_onCinematicEvent", params = { cinematicName = "cinematic.challengemodecomplete" }, ref = self }
		g_effectManager:cl_playNamedCinematic( "cinematic.challengemodecomplete", callbacks )
	end
end

function ChallengeVictoryWorld.cl_onCloseStuntman( self, name )
	self.cl.closedStuntmanGui = true
	self.cl.stuntmanGui:stopEffect( "UnlockBack", "Gui - Challengemode Stuntmanbackgroundshine", true )
end

function ChallengeVictoryWorld.cl_onCollectPressed( self, name )
	self.cl.closedStuntmanGui = true
	self.cl.stuntmanGui:playEffect( "UnlockBack","Gui - Stuntmancollectpressed", true  )
	self.cl.stuntmanGui:close()
end

function ChallengeVictoryWorld.cl_onCloseFinish( self, name )
	self.cl.closedFinishGui = true
	sm.event.sendToGame( "cl_e_leaveGame" )
end

function ChallengeVictoryWorld.cl_onFinishPressed( self, name )
	self.cl.closedFinishGui = true
	self.cl.finishGui:close()
end

function ChallengeVictoryWorld.cl_onCinematicEvent( self, eventName, params )
	params.eventName = eventName
	self.network:sendToServer( "sv_n_cinematicEvent", params )
	self.cl.cinematicAudioEffect:start()
end