require "zoneEditor"

local zoneEditorServer = {}


function zoneEditorServer.getModData(ID)
    local loadZones = ModData.getOrCreate(ID.."_zones")
    zoneEditor.loadedZones[ID] = loadZones
    return loadZones
end


function zoneEditorServer.pushUpdate(zoneType, zones)
    if isServer() then sendServerCommand(zoneEditor.MODULE, "loadZone", {zoneType=zoneType, zones=zones}) end
    zoneEditor.setZones(zoneType, zones)
end


function zoneEditorServer.sendTo(player, command, data)
    if isServer() then
        sendServerCommand(player, zoneEditor.MODULE, command, data)
    elseif command == "loadAll" then
        for zoneType,zones in pairs(data.loadedZones) do zoneEditor.setZones(zoneType, zones) end
    else
        zoneEditor.setZones(data.zoneType, data.zones)
    end
end


function zoneEditorServer.validType(zoneType) return type(zoneType) == "string" and #zoneType > 0 and #zoneType <= 128 end


function zoneEditorServer.cleanCoordinates(c)
    local clean = {}
    for _,k in ipairs({"x1","y1","x2","y2"}) do
        local v = type(c) == "table" and tonumber(c[k])
        clean[k] = v and math.floor(v) or -1
    end
    return clean
end


zoneEditorServer.restricted = {addZone=true, removeZone=true, editZoneData=true, setBounds=true, importZoneData=true}


function zoneEditorServer.onClientCommand(_module, _command, _player, _data)
    if _module ~= zoneEditor.MODULE then return end
    _data = _data or {}

    if zoneEditorServer.restricted[_command] then
        if not zoneEditorServer.validType(_data.zoneType) then return end
        if not zoneEditor.canEdit(_player, _data.zoneType) then
            print("ZoneEditor: rejected ".._command.." from "..tostring(_player and _player:getUsername()))
            return
        end
    end

    --sendClientCommand(player, "zoneEditor", "loadAll", {zoneTypes={"zoneTypeA","zoneTypeB"}})
    if _command == "loadAll" then
        local requested = {}
        for _,zoneType in ipairs(zoneEditor.zoneTypeOrder) do requested[zoneType] = true end
        if type(_data.zoneTypes) == "table" then
            for k,v in pairs(_data.zoneTypes) do
                local zoneType = type(k) == "string" and k or v
                if zoneEditorServer.validType(zoneType) then requested[zoneType] = true end
            end
        end

        local chamberedZones = {}
        for zoneType in pairs(requested) do chamberedZones[zoneType] = zoneEditorServer.getModData(zoneType) end
        zoneEditorServer.sendTo(_player, "loadAll", {loadedZones=chamberedZones})
        return
    end

    --sendClientCommand(player, "zoneEditor", "loadZone", {zoneType=zoneType})
    if _command == "loadZone" then
        if not zoneEditorServer.validType(_data.zoneType) then return end
        zoneEditorServer.sendTo(_player, "loadZone", {zoneType=_data.zoneType, zones=zoneEditorServer.getModData(_data.zoneType)})
        return
    end

    local zoneType = _data.zoneType
    if not zoneEditorServer.validType(zoneType) then return end
    local zones = zoneEditorServer.getModData(zoneType)

    --sendClientCommand(player, "zoneEditor", "addZone", {zoneType=zoneType, newZone=newZone})
    if _command == "addZone" then
        local newZone = _data.newZone
        if type(newZone) ~= "table" then return end
        newZone.coordinates = zoneEditorServer.cleanCoordinates(newZone.coordinates)
        table.insert(zones, newZone)
        zoneEditorServer.pushUpdate(zoneType, zones)
    end

    --sendClientCommand(player, "zoneEditor", "removeZone", {zoneType=zoneType, selected=index})
    if _command == "removeZone" then
        local remove = tonumber(_data.selected)
        if not remove or not zones[remove] then return end
        table.remove(zones, remove)
        zoneEditorServer.pushUpdate(zoneType, zones)
    end

    --sendClientCommand(player, "zoneEditor", "setBounds", {zoneType=zoneType, selected=index, x1=x1, y1=y1, x2=x2, y2=y2})
    if _command == "setBounds" then
        local selectedZone = zones[tonumber(_data.selected) or -1]
        if not selectedZone then return end
        selectedZone.coordinates = zoneEditorServer.cleanCoordinates(_data)
        zoneEditorServer.pushUpdate(zoneType, zones)
    end

    --sendClientCommand(player, "zoneEditor", "editZoneData", {zoneType=zoneType, selected=index, parentParam=parentParam, newKey=newKey, newValue=newValue})
    if _command == "editZoneData" then
        local selectedZone = zones[tonumber(_data.selected) or -1]
        if not selectedZone then print("ERROR: selectedZone not found.") return end
        if _data.newKey == nil then return end
        local parentParam = _data.parentParam
        local modifying = parentParam and selectedZone[parentParam] or selectedZone
        if type(modifying) ~= "table" then return end
        modifying[_data.newKey] = _data.newValue
        if parentParam == "coordinates" then selectedZone.coordinates = zoneEditorServer.cleanCoordinates(selectedZone.coordinates) end
        zoneEditorServer.pushUpdate(zoneType, zones)
    end

    --sendClientCommand(player, "zoneEditor", "importZoneData", {zoneType=zoneType, zones=tbl})
    if _command == "importZoneData" then
        local newZones = _data.zones
        if type(newZones) ~= "table" then return end
        for i=#zones, 1, -1 do table.remove(zones, i) end
        for _,newZone in pairs(newZones) do
            if type(newZone) == "table" then
                newZone.coordinates = zoneEditorServer.cleanCoordinates(newZone.coordinates)
                table.insert(zones, newZone)
            end
        end
        zoneEditorServer.pushUpdate(zoneType, zones)
    end
end


function zoneEditorServer.onInitGlobalModData(isNewGame)
    zoneEditor.globalModDataReady = true
    if isClient() then return end
    for _,zoneType in ipairs(zoneEditor.zoneTypeOrder) do
        zoneEditor.setZones(zoneType, zoneEditorServer.getModData(zoneType))
    end
end


return zoneEditorServer
