-- BallSpawner.lua --
dofile( "challenge_shapes.lua" )

BallSpawner = class()

BallSpawner.maxParentCount = 1
BallSpawner.maxChildCount = 0
BallSpawner.connectionInput = sm.interactable.connectionType.logic
BallSpawner.connectionOutput = sm.interactable.connectionType.none
BallSpawner.colorNormal = sm.color.new( 0xd84004ff )
BallSpawner.colorHighlight = sm.color.new( 0xde5f2eff )

--[[ Server ]]

-- (Event) Called upon creation on server
function BallSpawner.server_onCreate( self )
	self.interactable.active = false
	self.spawnedObject = nil
	self.spawnTimer = 0
end

-- (Event) Called upon game tick. (40 times a second)
function BallSpawner.server_onFixedUpdate( self, timeStep )
	if sm.challenge.hasStarted() then

		--Update active state
		local parent = self.interactable:getSingleParent()
		if parent then
			self.interactable.active = parent.active
		else
			self.interactable.active = true
		end

		if self.interactable.active then
			if self.spawnedObject == nil or not sm.exists( self.spawnedObject ) then -- No ball or ball was destroyed
				self.spawnTimer = self.spawnTimer + 1
				if self.spawnTimer >= 10 then
					local spawnPos = self.shape:getWorldPosition() + ( self.shape.at * 0.75 ) - sm.vec3.new( 0.625, 0.625, 0.625 )
	
					self.spawnedObject = sm.shape.createPart( obj_interactive_challengeball, spawnPos, sm.quat.identity(), true, true )
					self.spawnedObject.color = self.shape.color -- Blue spawners spawn blue ball
					
					self.network:sendToClients( "client_onBallSpawned" )

					self.spawnTimer = 0
				end
			end
		end
	end
end

--[[ Client ]]

-- (Event) Called upon creation on client
function BallSpawner.client_onCreate( self )
	self.activationEffect = sm.effect.createEffect( "Ballspawner - Activate", self.interactable )
end

-- (Event) Called upon through the network when creating a new ball
function BallSpawner.client_onBallSpawned( self )
	self.activationEffect:start()
end