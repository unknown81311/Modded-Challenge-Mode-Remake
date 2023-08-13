
function findInteractableWithType( collection, checkType )
	for _,result in ipairs( collection ) do
		if sm.exists( result ) then
			if type( result ) == "Body" then
				for _, shape in ipairs( result:getShapes() ) do
					local interactable = shape:getInteractable()
					if interactable and interactable:getType() == checkType then
						return interactable
					end
				end
			end
		end
	end
	return nil
end

function findSteering( collection )
	for _,result in ipairs( collection ) do
		if sm.exists( result ) then
			if type( result ) == "Body" then
				for _, shape in ipairs( result:getShapes() ) do
					local interactable = shape:getInteractable()
					if interactable and interactable:hasSteering() then
						return interactable
					end
				end
			end
		end
	end
	return nil
end

function CreateCharacterOnSpawner( world, player, playerSpawners, defaultPosition, enableHealth )
	local spawnPosition = defaultPosition
	local yaw = 0
	local pitch = 0
	if #playerSpawners > 0 then
		local spawnerIndex = ( ( player.id - 1 ) % #playerSpawners ) + 1
		local spawner = playerSpawners[spawnerIndex]
		if string.lower(type(spawner)) == "table" then
			spawnPosition = spawner.pos
			pitch = spawner.pitch
			yaw = spawner.yaw
		else
			spawnPosition = spawner.shape.worldPosition + spawner.shape:getAt() * 0.825
			local spawnDirection = -spawner.shape:getUp()
			pitch = math.asin( spawnDirection.z )
			yaw = math.atan2( spawnDirection.x, -spawnDirection.y )
		end
	end
	local character = sm.character.createCharacter( player, world, spawnPosition, yaw, pitch )
	player:setCharacter( character )
	sm.event.sendToPlayer( player, "sv_e_enableHealth", enableHealth )
end

function restrictAllBodies()
	local bodies = sm.body.getAllBodies()
	for _, body in ipairs( bodies ) do
		body:setBuildable( false )
		body:setErasable( false )
		body:setConnectable( false )
		body:setPaintable( false )
		body:setLiftable( false )
		body:setUsable( false )
		
		body:setDestructable( true )
	end
end

function addToArrayIfNotExists( array, value )
	local n = #array
	local exists = false
	for i = 1, n do
		if array[i] == value then
			return
		end
	end

	array[n + 1] = value
end

function removeFromArray( t, fnShouldRemove )
	local n = #t;
	local j = 1

	for i = 1, n do
		if fnShouldRemove( t[i] ) then
			t[i] = nil;
		else
			if i ~= j then
				t[j] = t[i];
				t[i] = nil;
			end
			j = j + 1;
		end
	end

	return t;
end

function Reverse_ipairs( a )
	if a == nil then a = {} end
	function iter( a, i )
		i = i - 1
		local v = a[i]
		if v then
			return i, v
		end
	end
	return iter, a, #a + 1
end

function defaultSettingValue( setting )
	if setting == "enable_client_toilet" then
		return true
	elseif setting == "enable_lift" then
		return true
	elseif setting == "enable_sledgehammer" then
		return false
	elseif setting == "enable_connecttool" then
		return true
	elseif setting == "enable_painttool" then
		return true
	elseif setting == "enable_weldtool" then
		return true
	elseif setting == "enable_handbook" then
		return true
	elseif setting == "enable_spudgun" then
		return false
	elseif setting == "enable_ammo_consumption" then
		return false
	elseif setting == "enable_fuel_consumption" then
		return false
	elseif setting == "enable_health" then
		return false
	end
	return nil
end

function getSettingValue( settings, name )
	if settings == nil or settings[name] == nil then
		return defaultSettingValue( name )
	else
		return settings[name]
	end
end
