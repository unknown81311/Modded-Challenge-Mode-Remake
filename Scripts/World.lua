dofile("$CONTENT_DATA/Scripts/Util.lua")
World = class( nil )
World.terrainScript = "$CONTENT_DATA/Scripts/terrain.lua"
World.cellMinX = -1
World.cellMaxX = 1
World.cellMinY = -1
World.cellMaxY = 1
World.worldBorder = true

function World.server_onCreate( self )
    print("World.server_onCreate")
    sm.event.sendToGame("server_worldScriptReady")
end

function World.server_updateGameState( self, state, caller )
    if not sm.isServerMode() or caller ~= nil then return end
    if type(state) == "string" then
        self.state = States.To(state)
    elseif type(state) == "number" then
        self.state = state
    end
end

function World.client_onCreate( self )
end

function World.server_onDestroy( self )
end

function World.client_onDestroy( self )
end

function World.server_onRefresh( self )
end

function World.client_onRefresh( self )
end

function World.server_onFixedUpdate( self, timeStep )
end

function World.client_onFixedUpdate( self, timeStep )
end

function World.client_onUpdate( self, deltaTime )
end

function World.client_onClientDataUpdate( self, data, channel )
end

function World.server_onCollision( self, objectA, objectB, position, pointVelocityA, pointVelocityB, normal )
end
function World.client_onCollision( self, objectA, objectB, position, pointVelocityA, pointVelocityB, normal )
end

function World.server_onCellCreated( self, x, y )
    print("CREATED", x, y)
end

function World.server_onCellLoaded( self, x, y )
end

function World.server_onCellUnloaded( self, x, y )
end

function World.server_onInteractableCreated( self, interactable )
end

function World.server_onInteractableDestroyed( self, interactable )
end

function World.server_onProjectile( self, position, airTime, velocity, projectileName, shooter, damage, customData, normal, target, uuid )
end

function World.server_onExplosion( self, center, destructionLevel )
end

function World.server_onMelee( self, position, attacker, target, damage, power, direction, normal )
end

function World.server_onProjectileFire( self, position, velocity, projectileName, shooter, uuid )
end

function World.client_onCellLoaded( self, x, y )
end

function World.client_onCellUnloaded( self, x, y )
end
