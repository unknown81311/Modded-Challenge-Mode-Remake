-- ExplosiveSpawner.lua --
dofile( "challenge_shapes.lua" )

ExplosiveSpawner = class()

ExplosiveSpawner.maxParentCount = 1
ExplosiveSpawner.maxChildCount = 0
ExplosiveSpawner.connectionInput = sm.interactable.connectionType.logic
ExplosiveSpawner.connectionOutput = sm.interactable.connectionType.none
ExplosiveSpawner.colorNormal = sm.color.new( 0xcb0a00ff )
ExplosiveSpawner.colorHighlight = sm.color.new( 0xee0a00ff )

--[[ Server ]]

-- (Event) Called upon creation on server
function ExplosiveSpawner.server_onCreate( self )
	self.interactable.active = false
	self.spawnedObject = nil
	self.spawnTimer = 0
	self.indestructibleTimer = 0
end

-- (Event) Called upon game tick. (40 times a second)
function ExplosiveSpawner.server_onFixedUpdate( self, timeStep )
	if sm.challenge.hasStarted() then

		--Update active state
		local parent = self.interactable:getSingleParent()
		if parent then
			self.interactable.active = parent.active
		else
			self.interactable.active = true
		end

		if self.interactable.active then
			if self.spawnedObject == nil or not sm.exists( self.spawnedObject ) then -- No tank or tank was destroyed
				self.spawnTimer = self.spawnTimer + 1
				if self.spawnTimer >= 10 then
					local spawnPos = self.shape:getWorldPosition() + ( self.shape.at * 0.125 ) - (self.shape.right * 0.375 + self.shape.up * 0.375)

					self.spawnedObject = sm.shape.createPart( obj_interactive_propanetank_large, spawnPos, self.shape.worldRotation, true, true )
					self.spawnedObject.color = self.shape.color -- Blue spawners spawn propanetanks

					self.spawnedObject.body.destructable = false
					self.spawnedObject.body.buildable = false
					self.spawnedObject.body.paintable = false
					self.spawnedObject.body.connectable = false
					self.spawnedObject.body.liftable = false
					self.spawnedObject.body.erasable = false

					-- Tank is indestructible for some time
					self.indestructibleTimer = 40 * 2

					self.network:sendToClients( "client_onTankSpawned" )

					self.spawnTimer = 0
				end
			end
		end

		if self.spawnedObject ~= nil and sm.exists( self.spawnedObject ) then
			if self.indestructibleTimer > 0 then
				self.indestructibleTimer = self.indestructibleTimer-1
				if self.indestructibleTimer <= 0 then
					-- Tank can now explode
					self.spawnedObject.body.destructable = true
				end
			end
		end
	end
end

--[[ Client ]]

-- (Event) Called upon creation on client
function ExplosiveSpawner.client_onCreate( self )
	self.activationEffect = sm.effect.createEffect( "Ballspawner - Activate", self.interactable )
end

-- (Event) Called upon through the network when creating a new ball
function ExplosiveSpawner.client_onTankSpawned( self )
	self.activationEffect:start()
end