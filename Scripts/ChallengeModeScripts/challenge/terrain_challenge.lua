
creations = nil
tiles = nil
bounds = {}

----------------------------------------------------------------------------------------------------
-- Initialization
----------------------------------------------------------------------------------------------------

function Init()
	print( "Initializing challenge terrain" )
end

----------------------------------------------------------------------------------------------------

function Create( xMin, xMax, yMin, yMax, seed, data )

	if xMin == 0 and xMax == 0 and yMin == 0 and yMax == 0 then
		xMin = -32
		xMax = 32
		yMin = -32
		yMax = 32
	end

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

function GetAssetsForCell( cellX, cellY, lod )
	if cellX == 0 and cellY == 0 then
		local retAssets = {}
		if tiles then
			for sUid,_ in pairs( tiles ) do
				local tileAssets = sm.terrainTile.getAssetsForCell( sm.uuid.new( sUid ), 0, 0, lod )
				for _,a in ipairs( tileAssets ) do
					retAssets[#retAssets + 1] = a
				end
			end
		end
		return retAssets
	end
	return {}
end

----------------------------------------------------------------------------------------------------

function GetNodesForCell( cellX, cellY )
	if cellX == 0 and cellY == 0 then
		local retNodes = {}
		if tiles then
			for sUid,_ in pairs( tiles ) do
				local tileNodes = sm.terrainTile.getNodesForCell( sm.uuid.new( sUid ), 0, 0 )
				for _,node in ipairs( tileNodes ) do
					retNodes[#retNodes + 1] = node
				end
			end
		end
		return retNodes
	end
	return {}
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
					c.bodyTransforms = true
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
		return tiles[tostring(uid)]
	end
	return ""
end
