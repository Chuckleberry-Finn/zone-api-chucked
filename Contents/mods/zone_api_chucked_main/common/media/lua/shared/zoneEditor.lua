zoneEditor = zoneEditor or {}
zoneEditor.zoneTypes = zoneEditor.zoneTypes or {}
zoneEditor.zoneTypeOrder = zoneEditor.zoneTypeOrder or {}
zoneEditor.loadedZones = zoneEditor.loadedZones or {}
zoneEditor.ignore = zoneEditor.ignore or {}
zoneEditor.listeners = zoneEditor.listeners or {}
zoneEditor.pendingRequests = zoneEditor.pendingRequests or {}

zoneEditor.MODULE = "zoneEditor"
zoneEditor.DEFAULT_CAPABILITY = "CanSetupNonPVPZone"


function zoneEditor.isSinglePlayer() return (not isClient()) and (not isServer()) end


function zoneEditor.addZoneType(fileName)
    if zoneEditor.zoneTypes[fileName] then return zoneEditor.zoneTypes[fileName] end

    local newZoneModule = require(fileName)

    if not newZoneModule then print("ERROR: ZoneType derived from: \""..fileName..".lua\" is returning nil.") return end
    if not newZoneModule.Zone then print("ERROR: ZoneType derived from: \""..fileName..".lua\" has no 'Zone'.") return end
    if not newZoneModule.Zone.coordinates then print("ERROR: ZoneType derived from: \""..fileName..".lua\" has no 'coordinates'.") return end

    if newZoneModule.ignore then
        for k,v in pairs(newZoneModule.ignore) do
            zoneEditor.ignore[k] = v
        end
    end

    zoneEditor.zoneTypes[fileName] = newZoneModule
    table.insert(zoneEditor.zoneTypeOrder, fileName)

    if (not isClient()) and zoneEditor.globalModDataReady then
        zoneEditor.loadedZones[fileName] = ModData.getOrCreate(fileName.."_zones")
    end

    return newZoneModule
end


function zoneEditor.getZoneTypeCapability(zoneType)
    local module = zoneEditor.zoneTypes[zoneType]
    return (module and module.capability) or zoneEditor.DEFAULT_CAPABILITY
end


function zoneEditor.getDisplayName(zoneType)
    local module = zoneEditor.zoneTypes[zoneType]
    return (module and module.displayName) or zoneType
end


---@param player IsoPlayer
---@param zoneType string|nil nil checks against any registered type
function zoneEditor.canEdit(player, zoneType)
    if not player then return false end
    if zoneEditor.isSinglePlayer() and getDebug() then return true end

    local role = player:getRole()
    if not role then return false end

    if not zoneType then
        for _,t in ipairs(zoneEditor.zoneTypeOrder) do
            if zoneEditor.canEdit(player, t) then return true end
        end
        return false
    end

    local cap = Capability[zoneEditor.getZoneTypeCapability(zoneType)] or Capability[zoneEditor.DEFAULT_CAPABILITY]
    return role:hasCapability(cap)
end


---Returns x1, y1, x2, y2 as min/max inclusive squares, or nil if unset.
function zoneEditor.getBounds(zone)
    local c = zone and zone.coordinates
    if type(c) ~= "table" then return end
    local x1, y1, x2, y2 = tonumber(c.x1), tonumber(c.y1), tonumber(c.x2), tonumber(c.y2)
    if not (x1 and y1 and x2 and y2) then return end
    if x1 < 0 or y1 < 0 or x2 < 0 or y2 < 0 then return end
    return math.min(x1,x2), math.min(y1,y2), math.max(x1,x2), math.max(y1,y2)
end


function zoneEditor.isPointInZone(zone, x, y)
    local x1, y1, x2, y2 = zoneEditor.getBounds(zone)
    if not x1 then return false end
    x, y = math.floor(x), math.floor(y)
    return x >= x1 and x <= x2 and y >= y1 and y <= y2
end


function zoneEditor.getZonesAt(zoneType, x, y)
    local found = {}
    local zones = zoneEditor.loadedZones[zoneType]
    if not zones then return found end
    for _,zone in ipairs(zones) do
        if zoneEditor.isPointInZone(zone, x, y) then table.insert(found, zone) end
    end
    return found
end


function zoneEditor.getZoneAt(zoneType, x, y)
    local zones = zoneEditor.loadedZones[zoneType]
    if not zones then return end
    for _,zone in ipairs(zones) do
        if zoneEditor.isPointInZone(zone, x, y) then return zone end
    end
end


function zoneEditor.requestZone(zoneID)
    local zones = zoneEditor.loadedZones[zoneID]
    if zones then return zones end
    if isClient() and not zoneEditor.pendingRequests[zoneID] then
        zoneEditor.pendingRequests[zoneID] = true
        sendClientCommand(getPlayer(), zoneEditor.MODULE, "loadZone", {zoneType=zoneID})
    end
end


function zoneEditor.addListener(func) table.insert(zoneEditor.listeners, func) end


function zoneEditor.setZones(zoneType, zones)
    zoneEditor.loadedZones[zoneType] = zones
    zoneEditor.pendingRequests[zoneType] = nil
    for _,func in ipairs(zoneEditor.listeners) do func(zoneType) end
end


function zoneEditor.tableToString(object,nesting)
    nesting = nesting or 0
    local indent = "    "
    local text = ""..string.rep(indent, nesting)
    if type(object) == 'table' then
        local s = "{\n"
        for k,v in pairs(object) do
            local key = type(k) == "number" and "["..k.."]" or "[\""..k.."\"]"
            s = s..string.rep(indent, nesting+1)..key.." = "..zoneEditor.tableToString(v,nesting+1)..",\n"
        end
        text = s..string.rep(indent, nesting).."}"
    else
        if type(object) == "string" then text = "\""..tostring(object).."\""
        else text = tostring(object)
        end
    end
    return text
end


function zoneEditor.stringToTable(inputString)
    local tblString = inputString and loadstring(("return "..inputString))
    local tblTable = tblString and tblString()
    return tblTable
end


return zoneEditor
