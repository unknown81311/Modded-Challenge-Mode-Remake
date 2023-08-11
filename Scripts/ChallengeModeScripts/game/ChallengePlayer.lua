dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_constants.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/util/Timer.lua" )
dofile( "$GAME_DATA/Scripts/game/BasePlayer.lua" )

ChallengePlayer = class( BasePlayer )

local StatsTickRate = 40
local PerMinute = StatsTickRate / ( 40 * 60 )
local HpRecovery = 50 * PerMinute
local RespawnTimeout = 60 * 40
local RespawnFadeDuration = 0.45
local RespawnEndFadeDuration = 0.45
local RespawnFadeTimeout = 5.0
local RespawnDelay = RespawnFadeDuration * 40
local RespawnEndDelay = 1.0 * 40
local BuilderBotUuid = sm.uuid.new( "b6cafd3e-970b-4974-bb9f-ba7184b02797" )

function ChallengePlayer.server_onCreate( self )
	self.sv = {}
	self.sv.saved = self.storage:load()
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.stats = {
			hp = 100, maxhp = 100
		}
		self.sv.saved.isConscious = true
		self.sv.saved.isNewPlayer = true
		self.sv.saved.inChemical = false
		self.sv.saved.inOil = false
		self.storage:save( self.sv.saved )
	end
	self:sv_init()
	self.network:setClientData( self.sv.saved )
end

function ChallengePlayer.server_onRefresh( self )
	self:sv_init()
	self.network:setClientData( self.sv.saved )
end

function ChallengePlayer.server_onInventoryChanges( self, container, changes )
	self.network:sendToClient( self.player, "cl_n_onInventoryChanges", { container = container, changes = changes } )
end

function ChallengePlayer.sv_init( self )
	BasePlayer.sv_init( self )
	self.sv.statsTimer = Timer()
	self.sv.statsTimer:start( StatsTickRate )
	self.sv.spawnparams = {}
end

function ChallengePlayer.client_onCancel( self )
	BasePlayer.client_onCancel( self )
	g_effectManager:cl_cancelAllCinematics()
end

function ChallengePlayer.client_onCreate( self )
	BasePlayer.client_onCreate( self )
	self.cl = self.cl or {}
	if self.player == sm.localPlayer.getPlayer() then
		if g_survivalHud then
			g_survivalHud:open()
		end
	end
end

function ChallengePlayer.client_onClientDataUpdate( self, data )
	BasePlayer.client_onClientDataUpdate( self, data )
	if sm.localPlayer.getPlayer() == self.player then
		if self.cl.stats == nil then self.cl.stats = data.stats end -- First time copy to avoid nil errors

		if g_survivalHud then
			g_survivalHud:setVisible( "HealthBar", data.enableHealth )
			g_survivalHud:setSliderData( "Health", data.stats.maxhp * 10 + 1, data.stats.hp * 10 )
		end

		self.cl.enableHealth = data.enableHealth
		self.cl.stats = data.stats
		self.cl.isConscious = data.isConscious
	end
end

function ChallengePlayer.cl_n_onInventoryChanges( self, params )
	if params.container == sm.localPlayer.getInventory() then
		for i, item in ipairs( params.changes ) do
			if item.difference > 0 then
				g_survivalHud:addToPickupDisplay( item.uuid, item.difference )
			end
		end
	end
end

function ChallengePlayer.cl_localPlayerUpdate( self, dt )
	BasePlayer.cl_localPlayerUpdate( self, dt )

	local character = self.player:getCharacter()
	if character and not self.cl.isConscious then
		local keyBindingText =  sm.gui.getKeyBinding( "Use", true )
		sm.gui.setInteractionText( "", keyBindingText, "#{INTERACTION_RESPAWN}" )
	end
end

function ChallengePlayer.client_onInteract( self, character, state )
	if state == true then
		if not self.cl.isConscious then
			self.network:sendToServer( "sv_n_tryRespawn" )
		end
	end
end

function ChallengePlayer.server_onFixedUpdate( self, dt )
	BasePlayer.server_onFixedUpdate( self, dt )

	-- Delays the respawn so clients have time to fade to black
	if self.sv.respawnDelayTimer then
		self.sv.respawnDelayTimer:tick()
		if self.sv.respawnDelayTimer:done() then
			self:sv_e_respawn()
			self.sv.respawnDelayTimer = nil
		end
	end

	-- End of respawn sequence
	if self.sv.respawnEndTimer then
		self.sv.respawnEndTimer:tick()
		if self.sv.respawnEndTimer:done() then
			self.network:sendToClient( self.player, "cl_n_endFadeToBlack", { duration = RespawnEndFadeDuration } )
			self.sv.respawnEndTimer = nil
		end
	end

	-- If respawn failed, restore the character
	if self.sv.respawnTimeoutTimer then
		self.sv.respawnTimeoutTimer:tick()
		if self.sv.respawnTimeoutTimer:done() then
			self:sv_e_onSpawnCharacter()
		end
	end

	local character = self.player:getCharacter()
	if character and self.sv.saved.isConscious and not g_godMode then
		self.sv.statsTimer:tick()
		if self.sv.statsTimer:done() then
			self.sv.statsTimer:start( StatsTickRate )

			self.sv.saved.stats.hp = math.min( self.sv.saved.stats.hp + HpRecovery, self.sv.saved.stats.maxhp )

			self.storage:save( self.sv.saved )
			self.network:setClientData( self.sv.saved )
		end
	end
end

function ChallengePlayer.sv_takeDamage( self, damage, source )
	if not sm.exists( self.player.character ) or  not sm.challenge.hasStarted() then
		return
	end
	if damage > 0 then
		damage = damage * GetDifficultySettings().playerTakeDamageMultiplier
		local character = self.player:getCharacter()
		local lockingInteractable = character:getLockingInteractable()
		if lockingInteractable and lockingInteractable:hasSeat() then
			lockingInteractable:setSeatCharacter( character )
		end

		if not g_godMode and self.sv.saved.enableHealth and self.sv.damageCooldown:done() then
			if self.sv.saved.isConscious then
				self.sv.saved.stats.hp = math.max( self.sv.saved.stats.hp - damage, 0 )

				print( "'ChallengePlayer' took:", damage, "damage.", self.sv.saved.stats.hp, "/", self.sv.saved.stats.maxhp, "HP" )

				if source then
					self.network:sendToClients( "cl_n_onEvent", { event = source, pos = character:getWorldPosition(), damage = damage * 0.01 } )
				else
					self.player:sendCharacterEvent( "hit" )
				end

				if self.sv.saved.stats.hp <= 0 then
					print( "'ChallengePlayer' knocked out!" )
					self.sv.respawnInteractionAttempted = false
					self.sv.saved.isConscious = false
					character:setTumbling( true )
					character:setDowned( true )
				end

				self.storage:save( self.sv.saved )
				self.network:setClientData( self.sv.saved )
			end
		else
			print( "'ChallengePlayer' resisted", damage, "damage" )
		end
	end
end

function ChallengePlayer.sv_n_tryRespawn( self )
	if not self.sv.saved.isConscious and not self.sv.respawnDelayTimer and not self.sv.respawnInteractionAttempted then
		self.sv.respawnInteractionAttempted = true
		self.sv.respawnEndTimer = nil
		self.network:sendToClient( self.player, "cl_n_startFadeToBlack", { duration = RespawnFadeDuration, timeout = RespawnFadeTimeout } )

		self.sv.respawnDelayTimer = Timer()
		self.sv.respawnDelayTimer:start( RespawnDelay )
	end
end

function ChallengePlayer.sv_e_respawn( self )
	if self.sv.spawnparams.respawn then
		if not self.sv.respawnTimeoutTimer then
			self.sv.respawnTimeoutTimer = Timer()
			self.sv.respawnTimeoutTimer:start( RespawnTimeout )
		end
		return
	end
	if not self.sv.saved.isConscious then
		self.sv.spawnparams.respawn = true
		sm.event.sendToGame( "sv_e_respawn", { player = self.player } )
	else
		print( "ChallengePlayer must be unconscious to respawn" )
	end
end

function ChallengePlayer.sv_e_onSpawnCharacter( self )
	if self.sv.spawnparams.respawn then
		self.sv.respawnEndTimer = Timer()
		self.sv.respawnEndTimer:start( RespawnEndDelay )
	end

	if self.sv.saved.isNewPlayer or self.sv.spawnparams.respawn or self.player.character:getCharacterType() == BuilderBotUuid then
		print( "ChallengePlayer", self.player.id, "spawned" )
		self.sv.saved.stats.hp = self.sv.saved.stats.maxhp
		self.sv.saved.isConscious = true
		self.sv.saved.isNewPlayer = false
		self.storage:save( self.sv.saved )
		self.network:setClientData( self.sv.saved )

		self.player.character:setTumbling( false )
		self.player.character:setDowned( false )
		self.sv.damageCooldown:start( 40 )
	else
		-- ChallengePlayer rejoined the game or fell off the map
		if self.sv.saved.stats.hp <= 0 or not self.sv.saved.isConscious then
			self.player.character:setTumbling( true )
			self.player.character:setDowned( true )
		end
	end

	self.sv.respawnInteractionAttempted = false
	self.sv.respawnDelayTimer = nil
	self.sv.respawnTimeoutTimer = nil
	self.sv.spawnparams = {}
end

function ChallengePlayer.sv_e_enableHealth( self, enableHealth )
	self.sv.saved.enableHealth = enableHealth
	self.network:setClientData( self.sv.saved )
end

function ChallengePlayer.sv_e_challengeReset( self )
	self.sv.saved.stats.hp = self.sv.saved.stats.maxhp
	self.sv.saved.isConscious = true
	if sm.exists( self.player.character ) then
		self.player.character:setTumbling( false )
		self.player.character:setDowned( false )
	end
	self.sv.damageCooldown:start( 40 )
	self.storage:save( self.sv.saved )
	self.network:setClientData( self.sv.saved )
end