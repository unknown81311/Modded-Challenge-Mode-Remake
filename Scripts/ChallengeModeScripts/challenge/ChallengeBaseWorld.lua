dofile( "$SURVIVAL_DATA/Scripts/game/managers/PesticideManager.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )

ChallengeBaseWorld = class( nil )

function ChallengeBaseWorld.server_onCreate( self )
	if self.waitingForDeath == true then return end
	self.pesticideManager = PesticideManager()
	self.pesticideManager:sv_onCreate()
end

function ChallengeBaseWorld.client_onCreate( self )
	if self.waitingForDeath == true then return end
	if self.pesticideManager == nil then
		assert( not sm.isHost )
		self.pesticideManager = PesticideManager()
	end
	self.pesticideManager:cl_onCreate()
end

function ChallengeBaseWorld.server_onFixedUpdate( self )
	if self.waitingForDeath == true then return end
	self.pesticideManager:sv_onWorldFixedUpdate( self )
end

function ChallengeBaseWorld.cl_n_pesticideMsg( self, msg )
	if self.waitingForDeath == true then return end
	self.pesticideManager[msg.fn]( self.pesticideManager, msg )
end

function ChallengeBaseWorld.server_onProjectileFire( self, firePos, fireVelocity, _, attacker, projectileUuid )
	if self.waitingForDeath == true then return end
	if isAnyOf( projectileUuid, g_potatoProjectiles ) then
		local units = sm.unit.getAllUnits()
		for i, unit in ipairs( units ) do
			if InSameWorld( self.world, unit ) then
				sm.event.sendToUnit( unit, "sv_e_worldEvent", { eventName = "projectileFire", firePos = firePos, fireVelocity = fireVelocity, projectileUuid = projectileUuid, attacker = attacker })
			end
		end
	end
end

function ChallengeBaseWorld.server_onInteractableCreated( self, interactable )
	if self.waitingForDeath == true then return end
	g_unitManager:sv_onInteractableCreated( interactable )
end

function ChallengeBaseWorld.server_onInteractableDestroyed( self, interactable )
	if self.waitingForDeath == true then return end
	g_unitManager:sv_onInteractableDestroyed( interactable )
end

function ChallengeBaseWorld.server_onProjectile( self, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, target, projectileUuid )
	if self.waitingForDeath == true then return end
	-- Notify units about projectile hit
	if isAnyOf( projectileUuid, g_potatoProjectiles ) then
		local units = sm.unit.getAllUnits()
		for i, unit in ipairs( units ) do
			if InSameWorld( self.world, unit ) then
				sm.event.sendToUnit( unit, "sv_e_worldEvent", { eventName = "projectileHit", hitPos = hitPos, hitTime = hitTime, hitVelocity = hitVelocity, attacker = attacker, damage = damage })
			end
		end
	end

	if projectileUuid == projectile_pesticide then
		local forward = sm.vec3.new( 0, 1, 0 )
		local randomDir = forward:rotateZ( math.random( 0, 359 ) )
		local effectPos = hitPos
		local success, result = sm.physics.raycast( hitPos + sm.vec3.new( 0, 0, 0.1 ), hitPos - sm.vec3.new( 0, 0, PESTICIDE_SIZE.z * 0.5 ), nil, sm.physics.filter.static + sm.physics.filter.dynamicBody )
		if success then
			effectPos = result.pointWorld + sm.vec3.new( 0, 0, PESTICIDE_SIZE.z * 0.5 )
		end
		self.pesticideManager:sv_addPesticide( self, effectPos, sm.vec3.getRotation( forward, randomDir ) )
	end

	--if projectileUuid == projectile_glowstick then
	--	sm.harvestable.createHarvestable( hvs_remains_glowstick, hitPos, sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), hitVelocity:normalize() ) )
	--end

	if projectileUuid == projectile_explosivetape then
		sm.physics.explode( hitPos, 7, 2.0, 6.0, 25.0, "RedTapeBot - ExplosivesHit" )
	end
end

function ChallengeBaseWorld.server_onCollision( self, objectA, objectB, collisionPosition, objectAPointVelocity, objectBPointVelocity, collisionNormal )
	if self.waitingForDeath == true then return end
	g_unitManager:sv_onWorldCollision( self, objectA, objectB, collisionPosition, objectAPointVelocity, objectBPointVelocity, collisionNormal )
end