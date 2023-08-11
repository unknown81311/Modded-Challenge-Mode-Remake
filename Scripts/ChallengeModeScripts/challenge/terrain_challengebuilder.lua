
creations = nil
tiles = nil
bounds = {}

----------------------------------------------------------------------------------------------------
-- Initialization
----------------------------------------------------------------------------------------------------

function Init()
	print( "Initializing challenge builder terrain" )
end

----------------------------------------------------------------------------------------------------

function Create( xMin, xMax, yMin, yMax, seed, data )
	--print( "X: "..xMin.." - "..xMax )
	--print( "Y: "..yMin.." - "..yMax )
	bounds.xMin = xMin
	bounds.xMax = xMax
	bounds.yMin = yMin
	bounds.yMax = yMax
	creations = data.levelCreations
	if data.tiles then
		tiles = {}
		for _,tile in ipairs( data.tiles ) do
			local uid = sm.terrainTile.getTileUuid( tile )
			tiles[tostring(uid)] = tile
		end
	end
end

----------------------------------------------------------------------------------------------------

function Load()
	return false -- "failed" load to force create
end

----------------------------------------------------------------------------------------------------
-- Utility
----------------------------------------------------------------------------------------------------

local function getCell( x, y )
	return math.floor( x / 64 ), math.floor( y / 64 )
end

local function insideCellBounds( cellX, cellY )
	if cellX < bounds.xMin or cellX > bounds.xMax then
		return false
	elseif cellY < bounds.yMin or cellY > bounds.yMax then
		return false
	end
	return true
end

----------------------------------------------------------------------------------------------------
-- Generator API Getters
----------------------------------------------------------------------------------------------------

function GetHeightAt( x, y, lod )
	return 0
end

function GetColorAt( x, y, lod )
	local cellX, cellY = getCell( x, y )
	if insideCellBounds( cellX, cellY ) then
		local brightness = 0.3
		if cellX % 2 == 0 then
			brightness = brightness + 0.1
		end
		if cellY % 2 == 0 then
			brightness = brightness + 0.1
		end
		return brightness, brightness, brightness
	end
	return 0, 0, 0
end

function GetMaterialAt( x, y, lod )
	return 0, 0, 0, 0, 0, 0, 0, 0
end

function GetClutterIdxAt( x, y )
	return -1
end

function GetEffectMaterialAt( x, y )
	return "Dirt"
end

----------------------------------------------------------------------------------------------------

local gnd = {
	uuid = sm.uuid.new( "688b6f02-3831-496b-9f80-8808bd5ff180" ), --Builder ground
	pos = sm.vec3.new( 32, 32, 0 ),
	rot = sm.quat.identity(),
	scale = sm.vec3.one()
}

function GetAssetsForCell( cellX, cellY, lod )
	local retAssets = {}
	if cellX == 0 and cellY == 0 then
		if tiles then
			for sUid,_ in pairs( tiles ) do
				local tileAssets = sm.terrainTile.getAssetsForCell( sm.uuid.new( sUid ), 0, 0, lod )
				for _,a in ipairs( tileAssets ) do
					retAssets[#retAssets + 1] = a
				end
			end
		end
	end
	retAssets[#retAssets + 1] = gnd
	return retAssets
end

----------------------------------------------------------------------------------------------------

function GetCreationsForCell( cellX, cellY )
	if cellX == 0 and cellY == 0 then
		local retCreations = {}
		if tiles then
			for sUid,_ in pairs( tiles ) do
				local tileCreations = sm.terrainTile.getCreationsForCell( sm.uuid.new( sUid ), 0, 0 )
				for _,c in ipairs( tileCreations ) do
					c.restricted = true
					retCreations[#retCreations + 1] = c
				end
			end
		end
		if creations then
			for _,creation in ipairs( creations ) do
				retCreations[#retCreations + 1] = { pathOrJson = creation, pos = sm.vec3.zero(), rot = sm.quat.identity(), bodyTransforms = true, restricted = true }
			end
		end
		return retCreations
	end
	return {}
 end
 
----------------------------------------------------------------------------------------------------
-- Tile Reader Path Getter
----------------------------------------------------------------------------------------------------

function GetTilePath( uid )
	if tiles then
		return tiles[tostring( uid )]
	end
	return ""
end
