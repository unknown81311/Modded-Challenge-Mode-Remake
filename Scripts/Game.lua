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

    self.ChallengeData = LoadChallengeData()
    
    self:server_updateGameState("PackMenu")
end

function Game.client_initializePackMenu( self )
    if self.ChallengeData == nil then
        self.ChallengeData = LoadChallengeData()
    end

    self.MenuInstance = {
        network = self.network,
        challenge_packs = self.ChallengeData.packs
    }

    if sm.exists(self.MenuInstance.blur) then
        self.MenuInstance.blur:open()
    else
        self.MenuInstance.blur = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/darken.layout", true, {
            isHud = true,
            isInteractive = false,
            needsCursor = false,
            hidesHotbar = false,
            isOverlapped = true,
            backgroundAlpha = 1,
        })
        self.MenuInstance.blur:setImage("BackgroundImage", "$CONTENT_DATA/preview.png")
        self.MenuInstance.blur:open()
    end

    if not sm.isHost then
        self.MenuInstance.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/ClientLoadingScreen.layout", true, {
            isHud = true,
            isInteractive = false,
            needsCursor = false,
            hidesHotbar = false,
            isOverlapped = true,
            backgroundAlpha = 0.5,
        })
        self.MenuInstance.gui:open()
    else
        sm.localPlayer.setLockedControls( true )

        _G["ChallengeModeMenuPack_LoadFunctions"](self.MenuInstance)

        if sm.exists(self.MenuInstance.gui) then
            self.MenuInstance.gui:open()
        else
            self.MenuInstance.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/ChallengeModeMenuPack.layout")
            self.MenuInstance.gui:setVisible("RecordContainer", false)
            self.MenuInstance.gui_table = sm.json.open( "$CONTENT_DATA/Scripts/ChallengeModeMenuPack.json" )
            for _,item in pairs(self.MenuInstance.gui_table.buttons) do
                self.MenuInstance.gui:setButtonCallback( item.name, item.method )
            end
            for _,item in pairs(self.MenuInstance.gui_table.text) do
                self.MenuInstance.gui:setTextChangedCallback( item.name, item.method )
            end
        end
        self.MenuInstance.ChallengeModeMenuPack_LOADED( self.MenuInstance )
    end
end

function Game.client_SelectChallenge( self, button )
    self.MenuInstance.client_SelectChallenge( self.MenuInstance, button )
end

function Game.client_DeselectAll( self )
    self.MenuInstance.client_DeselectAll( self.MenuInstance )
end

function Game.client_CloseMenu( self, button )
    self.MenuInstance.client_CloseMenu( self.MenuInstance, button )
end

function Game.client_SelectPack( self, button )
    self.MenuInstance.client_SelectPack( self.MenuInstance, button )
end

function Game.server_shutDownMenu( self )
    if self.MenuInstance ~= nil then
        if self.MenuInstance.gui ~= nil and self.MenuInstance.gui:isActive() then
            self.MenuInstance.gui:close()
        end
        if self.MenuInstance.blur ~= nil and self.MenuInstance.blur:isActive() then
            self.MenuInstance.blur:close()
        end
    end

    sm.localPlayer.setLockedControls( false )
end

function Game.server_initializeChallengeGame( self, uuid )
    self.network:sendToClients("server_shutDownMenu")
    
    local pack
    for _,p in pairs(self.ChallengeData.packs) do
        if p.uuid == uuid then
            pack = p
            break
        end
    end

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
    -- Init items
    if self.state == States.To("PackMenu") then
        self.network:sendToClients("client_initializePackMenu")
    end
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
    if self.state == States.To("PackMenu") or self.state == States.To("LevelMenu") then
        print(player.id)
        if isNewPlayer then
            if not sm.exists( self.sv.saved.world ) then
                sm.world.loadWorld( self.sv.saved.world )
            end
            self.sv.saved.world:loadCell( 0, 0, player, "sv_createPlayerCharacter" )
        end
        -- Send to all Client
        self.network:sendToClient(player, "client_updateGameState", State)
        -- Init menu
        if player.id ~= 1 then
            print("Loading Menu For:", player:getName())
            self.network:sendToClient(player,"client_initializePackMenu")
        end
    end

    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.server_onPlayerJoined( ChallengeGame, player, isNewPlayer )
    end
end

function Game.sv_createPlayerCharacter( self, world, x, y, player, params )
    local character = sm.character.createCharacter( player, world, sm.vec3.new( 0, 0, 5 ), 0, 0 )
	player:setCharacter( character )

    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.sv_createPlayerCharacter( ChallengeGame )
    end
end

--self:server_initializeChallengeGame()

function Game.server_onFixedUpdate( self, timeStep )
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

function Game.server_onChallengeCompleted( self, param )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.server_onChallengeCompleted(ChallengeGame, param)
    end
end

function Game.sv_e_respawn( self, params )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.sv_e_respawn(ChallengeGame, params)
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

function Game.client_onChallengeCompleted( self, params )
    if self.state == States.To("Play") or self.state == States.To("PlayBuild") or self.state == States.To("Build") then
        ChallengeGame.client_onChallengeCompleted(ChallengeGame, params)
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
        ChallengeGame.client_onUpdate( ChallengeGame, deltaTime )
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
    sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "_client_onLoadingScreenLifted")
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