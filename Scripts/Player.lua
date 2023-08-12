dofile("$CONTENT_DATA/Scripts/Util.lua")
Player = class( nil )

function Player.server_onCreate( self )
	print("Player.server_onCreate")
	self.start = sm.game.getCurrentTick()
	sm.event.sendToGame("server_playerScriptReady", self.player)
end

function Player.server_updateGameState( self, State, caller )
	if not sm.isServerMode() or caller ~= nil then return end
	if type(State) == "string" then
        self.state = States.To(State)
    elseif type(State) == "number" then
        self.state = State
    end
	self.network:sendToClients("client_updateGameState", self.state)

	if self.state == States.To("Play") then
		ChallengePlayer.player = self.player
		ChallengePlayer.storage = self.storage
		ChallengePlayer.network = self.network
		ChallengePlayer.server_ready = false
		self.network:sendToClient(self.player, "_client_onCreate")
    end
end

function Player.client_updateGameState( self, State, caller )
	if sm.isServerMode() or caller ~= nil then return end
	if type(State) == "string" then
        self.state = States.To(State)
    elseif type(State) == "number" then
        self.state = State
    end
end

function Player.cl_n_onEvent( self, data )
	ChallengePlayer.network = self.network
	ChallengePlayer.player = self.player
	BasePlayer.cl_n_onEvent(ChallengePlayer, data)
end

function Player.client_getMode( self, tool )
	sm.event.sendToTool( tool, "client_setMode", self.state)
end

function Player.cl_n_onInventoryChanges( self, data )
	if self.state == States.To("Play") then
		ChallengePlayer.cl_n_onInventoryChanges( ChallengePlayer, data )
	end
end

function Player._server_onCreate( self )
	if self.state == States.To("Play") then
		ChallengePlayer.network = self.network
		ChallengePlayer.server_onCreate( ChallengePlayer )
		ChallengePlayer.server_ready = true
	end
end

function Player._client_onCreate( self )
	if self.state == States.To("Play") then
		ChallengePlayer.network = self.network
		ChallengePlayer.player = self.player
		ChallengePlayer.client_onCreate( ChallengePlayer )
		self.network:sendToServer("_server_onCreate")
	end
end

function Player.client_onCreate( self )
	if self.state == States.To("Play") then
		ChallengePlayer.client_onCreate( ChallengePlayer )
	end
end

function Player.server_onDestroy( self )
	if self.state == States.To("Play") then
		ChallengePlayer.server_onDestroy( ChallengePlayer )
	end
end

function Player.client_onDestroy( self )
	if self.state == States.To("Play") then
		ChallengePlayer.client_onDestroy( ChallengePlayer )
	end
end

function Player.server_onRefresh( self )
	if self.state == States.To("Play") then
		ChallengePlayer.server_onRefresh( ChallengePlayer )
	end
end

function Player.client_onRefresh( self )
	if self.state == States.To("Play") then
		ChallengePlayer.client_onRefresh( ChallengePlayer )
	end
end


local waterSpeedFactor = 4 
function Player.server_onFixedUpdate( self, timeStep )
	-- build mode
	if self.state == 4 then
		if self.player.character ~= nil then
			if not self.player.character:isSwimming() then
				-- set thingies
				if sm.isHost then
					if self.player.character.publicData then
						self.player.character.publicData.waterMovementSpeedFraction = waterSpeedFactor
					end
				else
					if self.player.character.clientPublicData then
						self.player.character.clientPublicData.waterMovementSpeedFraction = waterSpeedFactor
					end
				end
				-- set swim
				self.player.character:setSwimming( true )
			end
		end
	end

	if self.state == States.To("Play") then
		if ChallengePlayer.server_ready == true then
			ChallengePlayer.network = self.network
			ChallengePlayer.server_onFixedUpdate( ChallengePlayer, timeStep )
		end
	end
end

function Player.client_onFixedUpdate( self, timeStep )
	if self.state == States.To("Play") then
		--ChallengePlayer.client_onFixedUpdate( ChallengePlayer, timeStep )
	end
end

function Player.client_onUpdate( self, deltaTime )
	if self.state == 0 or self.state == 1 then

	end
	if self.state == States.To("Play") then
		ChallengePlayer.client_onUpdate( ChallengePlayer, deltaTime )
	end
end

function Player.client_onClientDataUpdate( self, data, channel )
	if self.state == States.To("Play") then
		ChallengePlayer.client_onClientDataUpdate( ChallengePlayer, data )
	end
end

function Player.server_onProjectile( self, position, airTime, velocity, projectileName, shooter, damage, customData, normal, uuid )
	if self.state == States.To("Play") then
		ChallengePlayer.server_onProjectile( ChallengePlayer, position, airTime, velocity, projectileName, shooter, damage, customData, normal, uuid )
	end
end

function Player.server_onExplosion( self, center, destructionLevel )
	if self.state == States.To("Play") then
		ChallengePlayer.server_onExplosion( ChallengePlayer, center, destructionLevel )
	end
end

function Player.server_onMelee( self, position, attacker, damage, power, direction, normal )
	if self.state == States.To("Play") then
		ChallengePlayer.server_onMelee( ChallengePlayer, position, attacker, damage, power, direction, normal  )
	end
end

function Player.server_onCollision( self, other, position, selfPointVelocity, otherPointVelocity, normal )
	if self.state == States.To("Play") then
		ChallengePlayer.server_onCollision( ChallengePlayer, other, position, selfPointVelocity, otherPointVelocity, normal )
	end
end

function Player.server_onCollisionCrush( self )
	if self.state == States.To("Play") then
		--ChallengePlayer.server_onCollisionCrush( ChallengePlayer )
	end
end

function Player.server_onShapeRemoved( self, items )
    --items = { { uuid = uuid, amount = integer, type = string }, .. }
	if self.state == States.To("Play") then
		--ChallengePlayer.server_onShapeRemoved( ChallengePlayer, items )
	end
end

function Player.server_onInventoryChanges( self, inventory, changes )
    --changes = { { uuid = Uuid, difference = integer, tool = Tool }, .. }
	if self.state == States.To("Play") then
		self.network:sendToClient( self.player, "cl_n_onInventoryChanges", { container = container, changes = changes } )
	end
end

function Player.client_onInteract( self, character, state )
	if self.state == States.To("Play") then
		ChallengePlayer.network = self.network
		ChallengePlayer.client_onInteract( ChallengePlayer, character, state )
	end
end

function Player.sv_n_tryRespawn( self )
	if self.state == States.To("Play") then
		ChallengePlayer.sv_n_tryRespawn( ChallengePlayer, character, state )
	end
end

function Player.client_onCancel( self )
	if self.state == States.To("Play") then
		ChallengePlayer.client_onCancel( ChallengePlayer )
	end
end

function Player.client_onReload( self )
	if self.state == States.To("Play") then
		ChallengePlayer.client_onReload( ChallengePlayer )
	end
end

function Player.server_destroyCharacter( self )
	self.player:setCharacter(nil)
end

function Player._client_onLoadingScreenLifted( self )
	if self.state == States.To("PackMenu") or self.state == States.To("LevelMenu") then
		if self.player.character ~= nil then
			self.network:sendToServer("server_destroyCharacter")
		end
	end
end