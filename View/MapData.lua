local env, db = CPAPI.GetEnv(...)
---------------------------------------------------------------
-- MapData: Map data model with caching and pagination
---------------------------------------------------------------
local MapData = {}
env.MapData = MapData

---------------------------------------------------------------
-- Constants
---------------------------------------------------------------
local COMFORTABLE_MAX = 8   -- 45° spacing, most comfortable
local ACCEPTABLE_MAX  = 12  -- 30° spacing, slightly tight

---------------------------------------------------------------
-- Cache
---------------------------------------------------------------
local mapCache = {}  -- mapID -> { children = {...}, parentMapID = ... }

---------------------------------------------------------------
-- Get children for a map, with caching
---------------------------------------------------------------
function MapData.GetChildrenForMap(mapID)
    if not mapID then return {} end

    local cached = mapCache[mapID]
    if cached then return cached.children, cached.parentMapID end

    local children = {}
    local parentMapID

    -- Get parent map ID
    local mapInfo = C_Map.GetMapInfo(mapID)
    if mapInfo then
        parentMapID = mapInfo.parentMapID
    end

    -- Get child maps, filtering invalid ones
    local rawChildren = C_Map.GetMapChildrenInfo(mapID)
    if rawChildren then
        for _, childInfo in ipairs(rawChildren) do
            if C_Map.IsMapValidForNavBarDropdown(childInfo.mapID) then
                -- Check if this child has its own children (for navigation hint)
                local grandChildren = C_Map.GetMapChildrenInfo(childInfo.mapID)
                childInfo.hasChildren = (grandChildren and #grandChildren > 0) or false
                tinsert(children, childInfo)
            end
        end
        -- Sort by name for consistent ordering
        table.sort(children, function(a, b)
            return (a.name or '') < (b.name or '')
        end)
    end

    mapCache[mapID] = {
        children = children,
        parentMapID = parentMapID,
    }

    return children, parentMapID
end

---------------------------------------------------------------
-- Get layout configuration based on item count
---------------------------------------------------------------
function MapData.GetLayout(numItems)
    if numItems <= 0 then
        return nil
    elseif numItems <= COMFORTABLE_MAX then
        -- Comfortable: 1-8 items, 45° spacing
        return {
            perPage     = numItems,
            angle       = 360 / numItems,
            needPaging  = false,
            totalPages  = 1,
            size        = 500,  -- standard ring size
        }
    elseif numItems <= ACCEPTABLE_MAX then
        -- Acceptable: 9-12 items, 30° spacing, slightly larger ring
        return {
            perPage     = numItems,
            angle       = 360 / numItems,
            needPaging  = false,
            totalPages  = 1,
            size        = 560,
        }
    else
        -- Paged: >12 items, back to comfortable size with paging
        local totalPages = math.ceil(numItems / COMFORTABLE_MAX)
        return {
            perPage     = COMFORTABLE_MAX,
            angle       = 360 / COMFORTABLE_MAX,
            needPaging  = true,
            totalPages  = totalPages,
            size        = 500,
        }
    end
end

---------------------------------------------------------------
-- Get items for a specific page
---------------------------------------------------------------
function MapData.GetPage(children, page, perPage)
    local startIdx = (page - 1) * perPage + 1
    local endIdx = math.min(startIdx + perPage - 1, #children)

    local result = {}
    for i = startIdx, endIdx do
        tinsert(result, children[i])
    end
    return result
end

---------------------------------------------------------------
-- Get current map ID from WorldMapFrame
---------------------------------------------------------------
function MapData.GetCurrentMapID()
    if WorldMapFrame and WorldMapFrame:GetMapID() then
        return WorldMapFrame:GetMapID()
    end
    -- Fallback to player's current map
    return C_Map.GetBestMapForUnit('player')
end

---------------------------------------------------------------
-- Navigate to a map
---------------------------------------------------------------
function MapData.NavigateToMap(mapID)
    if not mapID then return end
    if WorldMapFrame then
        WorldMapFrame:SetMapID(mapID)
    end
end

---------------------------------------------------------------
-- Clear cache (called on map change)
---------------------------------------------------------------
function MapData.ClearCache()
    wipe(mapCache)
end

---------------------------------------------------------------
-- Get navigation hint for a map item
-- Returns whether this item has children (can drill down)
---------------------------------------------------------------
function MapData.HasChildren(mapID)
    if not mapID then return false end
    local children = C_Map.GetMapChildrenInfo(mapID)
    return children and #children > 0
end
