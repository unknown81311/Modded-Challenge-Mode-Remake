dofile("$CONTENT_DATA/Scripts/Util.lua")
Player = class( nil )

function Player.server_onCreate( self )
	print("Player.server_onCreate")
	self.start = sm.game.getCurrentTick()
	sm.event.sendToGame("server_playerScriptReady")
end

function Player.server_updateGameState( self, State, caller )
	if not sm.isServerMode() or caller ~= nil then return end
	if type(State) == "string" then
        self.state = States.To(State)
    elseif type(State) == "number" then
        self.state = State
    end
end

function Player.client_onCreate( self )
end

function Player.server_onDestroy( self )
end

function Player.client_onDestroy( self )
end

function Player.server_onRefresh( self )
end

function Player.client_onRefresh( self )
end


local waterSpeedFactor = 4 
function Player.server_onFixedUpdate( self, timeStep )
	-- menu mode
	if self.state == 0 or self.state == 1 then
		if self.player.character ~= nil
		and sm.game.getCurrentTick() - self.start > 50 then
			self.player:setCharacter(nil)
		end
		if self.state == 0 then

		else

		end
	end
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
end

function Player.client_onFixedUpdate( self, timeStep )
end

function Player.client_onUpdate( self, deltaTime )
	if self.state == 0 or self.state == 1 then

	end
end

function Player.client_onClientDataUpdate( self, data, channel )
end

function Player.server_onProjectile( self, position, airTime, velocity, projectileName, shooter, damage, customData, normal, uuid )
end

function Player.server_onExplosion( self, center, destructionLevel )
end

function Player.server_onMelee( self, position, attacker, damage, power, direction, normal )
end

function Player.server_onCollision( self, other, position, selfPointVelocity, otherPointVelocity, normal )
end

function Player.server_onCollisionCrush( self )
end

function Player.server_onShapeRemoved( self, items )
    --items = { { uuid = uuid, amount = integer, type = string }, .. }
end

function Player.server_onInventoryChanges( self, inventory, changes )
    --changes = { { uuid = Uuid, difference = integer, tool = Tool }, .. }
end

function Player.client_onInteract( self, character, state )
end

function Player.client_onCancel( self )
end

function Player.client_onReload( self )
end