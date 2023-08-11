dofile("$CONTENT_DATA/Scripts/Util.lua")
Game = class( nil )

function Game.server_onCreate( self )
	print("Game.server_onCreate")
    self.start_time = sm.game.getCurrentTick()
    self.respawn_all = false

    self.sv = {}
    if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.world = sm.world.createWorld( "$CONTENT_DATA/Scripts/World.lua", "World" )
	end

    self:server_updateGameState("PackMenu")
end

function Game.server_initializeChallengeGame( self )
    local items = LoadChallengeData()
    local pack = items.packs[1]
    sm.challenge.setChallengeUuid(pack.uuid)
    
    pack.startLevelIndex = 1
    ChallengeGame.data = pack
    ChallengeGame.network = self.network
    ChallengeGame.world = self.sv.saved.world
    
    sm.game.setLimitedInventory( ChallengeGame.enableLimitedInventory )
    sm.game.setEnableRestrictions( ChallengeGame.enableRestrictions )
    sm.game.setEnableAmmoConsumption( ChallengeGame.enableAmmoConsumption )
    sm.game.setEnableFuelConsumption( ChallengeGame.enableFuelConsumption )
    sm.game.setEnableUpgrade( ChallengeGame.enableUpgrade )
    
    self.network:sendToClients("client_initializeChallengeGame")
    self:server_updateGameState("Play")
    
    ChallengeGame.server_onCreate( ChallengeGame )
    --print(ChallengeGame.play.levelList[ChallengeGame.play.currentLevelIndex].data)
    --self.respawn_all = true
end

function Game.client_initializeChallengeGame( self )
    ChallengeGame.client_onCreate( ChallengeGame )
end

function Game.server_worldScriptReady( self, caller )
    -- Block Player Calls
    if not sm.isServerMode() or caller ~= nil then return end
    -- Update World Script
    if sm.exists(self.sv.saved.world) then
        sm.event.sendToWorld(self.sv.saved.world, "server_updateGameState", self.state)
    end
end

function Game.server_playerScriptReady( self, caller )
    -- Block Player Calls
    if not sm.isServerMode() or caller ~= nil then return end
    -- Update Players
    self:server_updateAllPlayerStates()
end

function Game.server_updateAllPlayerStates( self, caller )
    -- Update Player Scripts
    for _,player in pairs(sm.player.getAllPlayers()) do
        sm.event.sendToPlayer(player, "server_updateGameState", self.state)
    end
end

function Game.server_updateGameState( self, State, caller )
    -- Block Player Calls
    if not sm.isServerMode() or caller ~= nil then return end
    -- Update Self
    if type(State) == "string" then
        self.state = States.To(State)
    elseif type(State) == "number" then
        self.state = State
    end
    -- Send to all Clients
    self.network:sendToClients("client_updateGameState", State)
    -- Update World Script
    sm.event.sendToWorld(self.sv.saved.world, "server_updateGameState", state)
    -- Update Player Scripts
    self:server_updateAllPlayerStates()
end

function Game.client_updateGameState( self, State, caller )
    -- Block Player Calls, maybe
    if caller ~= nil or sm.isServerMode() then return end
    -- Update Self
    if type(State) == "string" then
        self.state = States.To(State)
    elseif type(State) == "number" then
        self.state = State
    end
end

function Game.server_onPlayerJoined( self, player, isNewPlayer )
    print("Game.server_onPlayerJoined")
    if isNewPlayer then
        if not sm.exists( self.sv.saved.world ) then
            sm.world.loadWorld( self.sv.saved.world )
        end
        self.sv.saved.world:loadCell( 0, 0, player, "sv_createPlayerCharacter" )
    end

    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.server_onPlayerJoined( ChallengeGame )
    end
end

function Game.sv_createPlayerCharacter( self, world, x, y, player, params )
    local character = sm.character.createCharacter( player, world, sm.vec3.new( 0, 0, 5 ), 0, 0 )
	player:setCharacter( character )

    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.sv_createPlayerCharacter( ChallengeGame )
    end
end

function Game.server_onFixedUpdate( self, timeStep )
    if sm.game.getCurrentTick() - self.start_time > 200 then
        if self.potato == nil then
            self:server_initializeChallengeGame()
            self.potato = true
        end
    end

    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.server_onFixedUpdate(ChallengeGame, timeStep)
        -- if self.respawn_all then
        --     if ChallengeGame.world ~= nil and sm.exists(ChallengeGame.world) then
        --         if sm.exists(ChallengeGame.activeWorld) then
        --             self.respawn_all = false
        --             for _,player in pairs(sm.player.getAllPlayers()) do
        --                 if player:getCharacter() == nil then
        --                     print("OH NO")
        --                     sm.event.sendToWorld( ChallengeGame.activeWorld, "server_spawnNewCharacter", { players = { player }, build = ChallengeGame.build } )
        --                     self.network:sendToClients( "client_sessionStarted", { sessionID = ChallengeGame.server_sessionID } )
        --                     if ChallengeGame.server_challengeCompleted then
        --                         sm.event.sendToWorld( ChallengeGame.activeWorld, "server_challengeCompleted" )
        --                         self.network:sendToClients( "client_onChallengeCompleted",
        --                             { time = ChallengeGame.server_completionTime, finalLevel = isFinalLevel( ChallengeGame.play ) } )
        --                     elseif ChallengeGame.server_challengeStarted then
        --                         sm.event.sendToWorld( ChallengeGame.activeWorld, "server_challengeStarted" )
        --                         self.network:sendToClients( "client_onChallengeStarted",
        --                             { ticksSinceStart = sm.game.getCurrentTick() - ChallengeGame.timerStartTick } )
        --                     end
        --                     g_unitManager:sv_onPlayerJoined( player )
        --                 end
        --             end
        --         end
        --     end
        -- end
    end
end

function Game.server_worldReadyForPlayers( self )
    sm.event.sendToWorld( ChallengeGame.world, "server_spawnCharacter", { players = sm.player.getAllPlayers() } )
end

function Game.server_onCellLoadComplete( self, data )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.server_onCellLoadComplete( ChallengeGame, data )
    end
end

function Game.server_getLevelData( self )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.server_getLevelData( ChallengeGame )
    end
end

function Game.server_getLevelUuid( self )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.server_getLevelUuid( ChallengeGame )
    end
end

function Game.server_onFinishedLoadContent( self )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.server_onFinishedLoadContent( ChallengeGame )
    end
end

function Game.server_onChallengeStarted( self )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.server_onChallengeStarted(ChallengeGame)
    end
end

function Game.server_onChallengeCompleted( self )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.server_onChallengeCompleted(ChallengeGame)
    end
end

function Game.sv_e_respawn( self )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.sv_e_respawn(ChallengeGame)
    end
end

function Game.setupMessageGui( self )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.setupMessageGui(ChallengeGame)
    end
end

function Game.setupHUD( self )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.setupHUD(ChallengeGame)
    end
end

function Game.client_showMessage( self, params )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.client_showMessage(ChallengeGame, params)
    end
end

function Game.client_onNextPressed( self )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.client_onNextPressed(ChallengeGame)
    end
end

function Game.client_onResetPressed( self )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.client_onResetPressed(ChallengeGame)
    end
end

function Game.client_onChallengeReset( self )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.client_onChallengeReset(ChallengeGame)
    end
end

function Game.client_onChallengeStarted( self, params )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.client_onChallengeStarted(ChallengeGame, params)
    end
end

function Game.client_onChallengeCompleted( self )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.client_onChallengeCompleted(ChallengeGame)
    end
end

function Game.client_sessionStarted( self, id )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.client_sessionStarted(ChallengeGame, id)
    end
end

function Game.cl_e_leaveGame( self )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        --ChallengeGame.cl_e_leaveGame(ChallengeGame)
    end
end

function Game.client_onCreate( self )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.client_onCreate( ChallengeGame )
    end
end

function Game.server_onDestroy( self )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.server_onDestroy( ChallengeGame )
    end
end

function Game.client_onDestroy( self )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.client_onDestroy( ChallengeGame )
    end
end

function Game.server_onRefresh( self )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.server_onRefresh( ChallengeGame )
    end
end

function Game.client_onRefresh( self )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        --ChallengeGame.client_onRefresh( ChallengeGame )
    end
end

function Game.client_onFixedUpdate( self, timeStep )
    --if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        --ChallengeGame.client_onFixedUpdate( ChallengeGame )
    --end
end

function Game.client_onUpdate( self, deltaTime )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.client_onUpdate( ChallengeGame )
    end
end

function Game.client_onClientDataUpdate( self, data, channel )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.client_onClientDataUpdate( ChallengeGame )
    end
end

function Game.server_onNextPressed( self, data, channel )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.server_onNextPressed( ChallengeGame )
    end
end

function Game.server_onResetPressed( self, data, channel )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.server_onResetPressed( ChallengeGame )
    end
end

function Game.server_onFinishPressed( self, data, channel )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.server_onFinishPressed( ChallengeGame )
    end
end

function Game.server_start( self, player )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.server_start( ChallengeGame )
    end
end

function Game.server_onPlayerLeft( self, player )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        --ChallengeGame.server_onPlayerLeft( ChallengeGame )
    end
end

function Game.server_onReset( self )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.server_onReset( ChallengeGame )
    end
end

function Game.server_onRestart( self )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.server_onRestart( ChallengeGame )
    end
end

function Game.server_onSaveLevel( self )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.server_onSaveLevel( ChallengeGame )
    end
end

function Game.server_onTestLevel( self )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.server_onTestLevel( ChallengeGame )
    end
end

function Game.server_onStopTest( self )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.server_onStopTest( ChallengeGame )
    end
end

function Game.client_onLoadingScreenLifted( self )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.client_onLoadingScreenLifted( ChallengeGame )
    end
end

function Game.sv_loadVictoryLevel( self )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.sv_loadVictoryLevel( ChallengeGame )
    end
end

function Game.client_onLanguageChange( self, language )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.client_onLanguageChange( ChallengeGame )
    end
end

function Game.server_loadLevel( self, loadJsonData, loadSaveData )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.server_loadLevel( ChallengeGame, loadJsonData, loadSaveData )
    end
end

function Game.server_loadJsonData( self, language )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.server_loadJsonData( ChallengeGame )
    end
end

function Game.server_loadSaveData( self, language )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.server_loadSaveData( ChallengeGame )
    end
end