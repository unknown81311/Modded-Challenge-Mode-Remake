dofile("$CONTENT_DATA/Scripts/Util.lua")
Game = class( nil )

function Game.server_onCreate( self )
	print("Game.server_onCreate")
    self.start_time = sm.game.getCurrentTick()
    self.respawn_all = 0

    -- sm.world.setWorldStorage( self.storage )
    
    -- local worlds = self.storage:load()
    -- if worlds ~= nil then
    --     for _,world in pairs(worlds) do
    --         if sm.exists(world) then
    --             world:destroy()
    --         end
    --     end
    -- end
    self.worldDestroyQueue = {}
    self.sv = {}
    if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.world = sm.world.createWorld( "$CONTENT_DATA/Scripts/World.lua", "World" )
	end

    self.ChallengeData = LoadChallengeData()
    
    self:server_updateGameState("PackMenu")
end

function Game.client_initializeMenu( self, force )
    if self.MenuInstance == nil or force == true then
        self.MenuInstance = {
            blur = {
                gui = nil,
                network = self.network
            },
            pack = {
                gui = nil,
                network = self.network,
                challenge_packs = self.ChallengeData.packs,
                client_initializeLevelMenu = self.client_initializeLevelMenu
            },
            level = {
                gui = nil,
                challenge_levels = self.ChallengeData.levels,
                network = self.network
            }
        }
    end
end

function Game.client_initializeBackground( self )
    if sm.exists(self.MenuInstance.blur.gui) then
        self.MenuInstance.blur.gui:open()
    else
        self.MenuInstance.blur.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/darken.layout", true, {
            isHud = true,
            isInteractive = false,
            needsCursor = false,
            hidesHotbar = false,
            isOverlapped = true,
            backgroundAlpha = 1,
        })
        self.MenuInstance.blur.gui:setImage("BackgroundImage", "$CONTENT_DATA/preview.png")
        self.MenuInstance.blur.gui:open()
    end
end

function Game.client_initializePackMenu( self, force )
    if self.ChallengeData == nil then
        self.ChallengeData = LoadChallengeData()
    end
    
    self:client_initializeMenu(force)
    self:client_initializeBackground()

    if not sm.isHost then
        self.MenuInstance.pack.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/ClientLoadingScreen.layout", true, {
            isHud = true,
            isInteractive = false,
            needsCursor = false,
            hidesHotbar = false,
            isOverlapped = true,
            backgroundAlpha = 0.5,
        })
        self.MenuInstance.pack.gui:open()
    else
        sm.localPlayer.setLockedControls( true )
        if sm.exists(self.MenuInstance.pack.gui) and force ~= true then
            self.MenuInstance.pack.gui:open()
        else
            _G["ChallengeModeMenuPack_LoadFunctions"](self.MenuInstance.pack)
            self.MenuInstance.pack.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/ChallengeModeMenuPack.layout")
            self.MenuInstance.pack.gui:setVisible("RecordContainer", false)
            self.MenuInstance.pack.gui_table = sm.json.open( "$CONTENT_DATA/Scripts/ChallengeModeMenuPack.json" )
            for _,item in pairs(self.MenuInstance.pack.gui_table.buttons) do
                self.MenuInstance.pack.gui:setButtonCallback( item.name, item.method )
            end
            for _,item in pairs(self.MenuInstance.pack.gui_table.text) do
                self.MenuInstance.pack.gui:setTextChangedCallback( item.name, item.method )
            end
        end
        self.MenuInstance.pack.ChallengeModeMenuPack_LOADED( self.MenuInstance.pack )
    end
end

function Game.server_exitToMenu( self )
    if sm.exists(ChallengeGame.world) then
        ChallengeGame.world:destroy()
        ChallengeGame.world = nil
    end
    if not sm.exists(self.sv.saved.world) then
        self.sv.saved.world = sm.world.createWorld( "$CONTENT_DATA/Scripts/World.lua", "World" )
    end
    self.respawn_all = 2
    self:server_updateGameState("PackMenu")
end

function Game.client_initializeLevelMenu( self, force )
    self:client_initializeMenu()
    self:client_initializeBackground()

    if sm.exists(self.MenuInstance.level.gui) and force ~= true then
        self.MenuInstance.level.gui:open()
    else
        _G["ChallengeBuilder_LoadFunctions"](self.MenuInstance.level)
        self.MenuInstance.level.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/ChallengeBuilder.layout")
        self.MenuInstance.level.gui:setVisible("RecordContainer", false)
        self.MenuInstance.level.level_table = sm.json.open( "$CONTENT_DATA/Scripts/ChallengeBuilder.json" )
        for _,item in pairs(self.MenuInstance.level.level_table.buttons) do
            self.MenuInstance.level.gui:setButtonCallback( item.name, item.method )
        end
        for _,item in pairs(self.MenuInstance.level.level_table.text) do
            self.MenuInstance.level.gui:setTextChangedCallback( item.name, item.method )
        end
    end
    self.MenuInstance.level.ChallengeBuilder_LOADED( self.MenuInstance.level )
end

function Game.client_level_ChangeTitle( self, button )
    self.MenuInstance.level.client_ChangeTitle( self.MenuInstance.level, button )
end

function Game.client_level_AddChallenge( self, button )
    self.MenuInstance.level.client_AddChallenge( self.MenuInstance.level, button )
end

function Game.client_level_ChangeDescription( self, button )
    self.MenuInstance.level.client_ChangeDescription( self.MenuInstance.level, button )
end

function Game.client_level_BuildChallenge( self, button )
    self.MenuInstance.level.client_BuildChallenge( self.MenuInstance.level, button )
end

function Game.client_level_PlayChallenge( self, button )
    self.MenuInstance.level.client_PlayChallenge( self.MenuInstance.level, button )
end

function Game.client_level_OpenGui( self )
    --self.MenuInstance.blur.gui:close()
    self.MenuInstance.level.gui:close()
    --self.MenuInstance.pack.gui:open()
    self:client_initializePackMenu(true)
end

function Game.client_level_SelectChallenge( self, button )
    self.MenuInstance.level.client_SelectChallenge( self.MenuInstance.level, button )
end

function Game.client_level_DeselectAll( self )
    self.MenuInstance.level.client_DeselectAll( self.MenuInstance.level )
end

function Game.client_pack_OpenGui( self, button )
    self.MenuInstance.pack.gui:close()
    self:client_initializeLevelMenu(true)
    --self.MenuInstance.pack.client_OpenGui( self.MenuInstance.pack, button )
end

function Game.client_pack_SelectChallenge( self, button )
    self.MenuInstance.pack.client_SelectChallenge( self.MenuInstance.pack, button )
end

function Game.client_pack_DeselectAll( self )
    self.MenuInstance.pack.client_DeselectAll( self.MenuInstance.pack )
end

function Game.client_pack_CloseMenu( self, button )
    self.MenuInstance.pack.client_CloseMenu( self.MenuInstance.pack, button )
end

function Game.client_pack_SelectPack( self, button )
    self.MenuInstance.pack.client_SelectPack( self.MenuInstance.pack, button )
end

function Game.server_shutDownMenu( self )
    if self.MenuInstance ~= nil then
        if self.MenuInstance.pack.gui ~= nil and self.MenuInstance.pack.gui:isActive() then
            self.MenuInstance.pack.gui:close()
        end
        if self.MenuInstance.blur.gui ~= nil and self.MenuInstance.blur.gui:isActive() then
            self.MenuInstance.blur.gui:close()
        end
        if self.MenuInstance.level.gui ~= nil and self.MenuInstance.level.gui:isActive() then
            self.MenuInstance.level.gui:close()
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

function Game.sve_destroyWorld( self, world )
    table.insert(self.worldDestroyQueue, {world = world, time = 21})
end

function Game.server_playerScriptReady( self, player, caller )
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
        self.state = States.To[State]
    elseif type(State) == "number" then
        self.state = State
    end
    -- Send to all Clients
    self.network:sendToClients("client_updateGameState", State)
    -- Init items
    if self.state == States.To.PackMenu then
        self.network:sendToClients("client_initializePackMenu", true)
    elseif self.state == States.To.LevelMenu then

    else
        
    end
    -- Update World Script
    sm.event.sendToWorld(self.sv.saved.world, "server_updateGameState", State)
    -- Update Player Scripts
    self:server_updateAllPlayerStates()
end

function Game.client_updateGameState( self, State, caller )
    -- Block Player Calls, maybe
    if caller ~= nil or sm.isServerMode() then return end
    -- Update Self
    if type(State) == "string" then
        self.state = States.To[State]
    elseif type(State) == "number" then
        self.state = State
    end
end

function Game.server_onPlayerJoined( self, player, isNewPlayer )
    print("Game.server_onPlayerJoined")
    if sm.host == nil then
        sm.host = sm.player.getAllPlayers()[1]
    end
    if self.state == States.To.PackMenu or self.state == States.To.LevelMenu then
        if not sm.exists( self.sv.saved.world ) then
            sm.world.loadWorld( self.sv.saved.world )
        end
        self.sv.saved.world:loadCell( 0, 0, player, "sv_createPlayerCharacter" )
        -- Send to all Client
        self.network:sendToClient(player, "client_updateGameState", State)
        -- Init menu
        if player ~= sm.host then
            self.network:sendToClient(player, "client_initializePackMenu")
        end
    end

    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.server_onPlayerJoined( ChallengeGame, player, isNewPlayer )
    end
end

function Game.sv_createPlayerCharacter( self, world, x, y, player, params )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        sm.event.sendToWorld( world, "server_spawnCharacter", { players = { player }, playCutscene = false})
    else
        local character = sm.character.createCharacter( player, world, sm.vec3.new( 0, 0, 5 ), 0, 0 )
	    player:setCharacter( character )
    end
end

--self:server_initializeChallengeGame()

function Game.server_onFixedUpdate( self, timeStep )
    if self.state == States.To.PackMenu or self.state == States.To.LevelMenu then
        if #self.worldDestroyQueue > 0 then
            self.respawn_all = 1
        end
        for index,item in pairs(self.worldDestroyQueue) do
            if item ~= nil and sm.exists(item.world) then
                if item.time > 0 then
                    item.time = item.time - 1
                else
                    item.world:destroy()
                    table.remove(self.worldDestroyQueue, index)
                end
            end
        end
        if #self.worldDestroyQueue == 0 and self.respawn_all == 1 then
            self.respawn_all = 2
        end
        if self.respawn_all == 2 then
            for _,player in pairs(sm.player.getAllPlayers()) do 
                self:server_onPlayerJoined(player, false)
            end
            self.respawn_all = 0
        end
    elseif self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
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

function Game.server_spawnNewCharacter( self, params, caller )
    sm.event.sendToWorld(ChallengeGame.world, "server_spawnNewCharacter", params)
end

function Game.server_worldReadyForPlayers( self )
    sm.event.sendToWorld( ChallengeGame.world, "server_spawnCharacter", { players = sm.player.getAllPlayers() } )
end

function Game.server_onCellLoadComplete( self, data )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.server_onCellLoadComplete( ChallengeGame, data )
    end
end

function Game.server_getLevelData( self )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.server_getLevelData( ChallengeGame )
    end
end

function Game.server_getLevelUuid( self )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.server_getLevelUuid( ChallengeGame )
    end
end

function Game.server_onFinishedLoadContent( self )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.server_onFinishedLoadContent( ChallengeGame )
    end
end

function Game.server_onChallengeStarted( self )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.server_onChallengeStarted(ChallengeGame)
    end
end

function Game.server_onChallengeCompleted( self, param )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.server_onChallengeCompleted(ChallengeGame, param)
    end
end

function Game.sv_e_respawn( self, params )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.sv_e_respawn(ChallengeGame, params)
    end
end

function Game.setupMessageGui( self )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.setupMessageGui(ChallengeGame)
    end
end

function Game.setupHUD( self )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.setupHUD(ChallengeGame)
    end
end

function Game.client_showMessage( self, params )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.client_showMessage(ChallengeGame, params)
    end
end

function Game.client_onNextPressed( self )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.network = self.network
        ChallengeGame.client_onNextPressed(ChallengeGame)
    end
end

function Game.client_onResetPressed( self )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.network = self.network
        ChallengeGame.client_onResetPressed(ChallengeGame)
    end
end

function Game.client_onChallengeReset( self )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.client_onChallengeReset(ChallengeGame)
    end
end

function Game.client_onChallengeStarted( self, params )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.client_onChallengeStarted(ChallengeGame, params)
    end
end

function Game.client_onChallengeCompleted( self, params )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.client_onChallengeCompleted(ChallengeGame, params)
    end
end

function Game.client_sessionStarted( self, id )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.client_sessionStarted(ChallengeGame, id)
    end
end

function Game.cl_e_leaveGame( self )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        --ChallengeGame.cl_e_leaveGame(ChallengeGame)
    end
end

function Game.client_onCreate( self )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.client_onCreate( ChallengeGame )
    end
end

function Game.server_onDestroy( self )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.server_onDestroy( ChallengeGame )
    end
end

function Game.client_onDestroy( self )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.client_onDestroy( ChallengeGame )
    end
end

function Game.server_onRefresh( self )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.server_onRefresh( ChallengeGame )
    end
end

function Game.client_onRefresh( self )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        --ChallengeGame.client_onRefresh( ChallengeGame )
    end
end

function Game._server_onReset( self )
    if self.state == States.To.Play or self.state == States.To.PlayBuild then
        ChallengeGame.server_onReset(ChallengeGame)
    end
end

function Game._server_onRestart( self )
    if self.state == States.To.Play or self.state == States.To.PlayBuild then
        ChallengeGame.server_onRestart(ChallengeGame)
    end
end

function Game._server_onSaveLevel( self )
    if self.state == States.To.Build then
        ChallengeGame.server_onSaveLevel(ChallengeGame)
    end
end

function Game._server_onTestLevel( self )
    if self.state == States.To.Build then
        self:server_updateGameState("PlayBuild")
        ChallengeGame.server_onTestLevel(ChallengeGame)
    end
end

function Game._server_onStopTest( self )
    if self.state == States.To.PlayBuild then
        self:server_updateGameState("Build")
        ChallengeGame.server_onStopTest(ChallengeGame)
    end
end

function Game.client_onFixedUpdate( self, timeStep )
    if self.state == States.To.PackMenu then
        if sm.exists(self.MenuInstance.pack.gui) then
            if not self.MenuInstance.pack.gui:isActive() then
                self.MenuInstance.pack.gui:open()
            end
        end
    elseif self.state == States.To.LevelMenu then
        if sm.exists(self.MenuInstance.level.gui) then
            if not self.MenuInstance.level.gui:isActive() then
                self.MenuInstance.level.gui:open()
            end
        end
    end
    --if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        --ChallengeGame.client_onFixedUpdate( ChallengeGame )
    --end
end

function Game.client_onUpdate( self, deltaTime )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.client_onUpdate( ChallengeGame, deltaTime )
    end
end

function Game.client_onClientDataUpdate( self, data, channel )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.client_onClientDataUpdate( ChallengeGame )
    end
end

function Game.server_onNextPressed( self, data, channel )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.server_onNextPressed( ChallengeGame )
    end
end

function Game.server_onResetPressed( self, data )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.server_onResetPressed( ChallengeGame, data )
    end
end

function Game.server_onFinishPressed( self, data, channel )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.server_onFinishPressed( ChallengeGame )
    end
end

function Game.server_start( self, player )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.server_start( ChallengeGame )
    end
end

function Game.server_onPlayerLeft( self, player )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        --ChallengeGame.server_onPlayerLeft( ChallengeGame )
    end
end

function Game.server_onReset( self )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.server_onReset( ChallengeGame )
    end
end

function Game.server_onRestart( self )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.server_onRestart( ChallengeGame )
    end
end

function Game.server_onSaveLevel( self )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.server_onSaveLevel( ChallengeGame )
    end
end

function Game.server_onTestLevel( self )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.server_onTestLevel( ChallengeGame )
    end
end

function Game.server_onStopTest( self )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.server_onStopTest( ChallengeGame )
    end
end

function Game.client_onLoadingScreenLifted( self )
    sm.event.sendToPlayer(sm.localPlayer.getPlayer(), "_client_onLoadingScreenLifted")
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.client_onLoadingScreenLifted( ChallengeGame )
    end
end

function Game.sv_loadVictoryLevel( self )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.sv_loadVictoryLevel( ChallengeGame )
    end
end

function Game.client_onLanguageChange( self, language )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.client_onLanguageChange( ChallengeGame )
    end
end

function Game.server_loadLevel( self, loadJsonData, loadSaveData )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.server_loadLevel( ChallengeGame, loadJsonData, loadSaveData )
    end
end

function Game.server_loadJsonData( self, language )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.server_loadJsonData( ChallengeGame )
    end
end

function Game.server_loadSaveData( self, language )
    if self.state == States.To.Play or self.state == States.To.PlayBuild or self.state == States.To.Build then
        ChallengeGame.server_loadSaveData( ChallengeGame )
    end
end