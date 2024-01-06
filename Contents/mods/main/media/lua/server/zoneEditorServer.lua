local zoneEditorServer = {}

zoneEditorServer.loadedZones = {}
function zoneEditorServer.getModData(ID)
    if isServer() then
        zoneEditorServer.loadedZones[ID] = zoneEditorServer.loadedZones[ID] or ModData.getOrCreate(ID.."_zones")
        return zoneEditorServer.loadedZones[ID]
    else
        zoneEditor.loadedZones[ID] = zoneEditor.loadedZones[ID] or ModData.getOrCreate(ID.."_zones")
        return zoneEditor.loadedZones[ID]
    end
end


function zoneEditorServer.pushUpdate(zoneType, zones, disableRefresh)
    if isServer() then
        sendServerCommand("zoneEditor", "loadZone", {zoneType=zoneType, zones=zones, disableRefresh=disableRefresh})
    else
        zoneEditorServer.loadedZones[zoneType] = zones
        zoneEditor.loadedZones[zoneType] = zones
        if (not disableRefresh) and zoneEditor.instance then zoneEditor.instance.refresh = 1 end
    end
end


function zoneEditorServer.onClientCommand(_module, _command, _player, _data)
    if _module ~= "zoneEditor" then return end
    _data = _data or {}

    if _command == "loadAll" then
        if isServer() then
            local loadZones = _data.zoneTypes

            local chamberedZones = {}

            for zoneType,zoneData in pairs(loadZones) do
                chamberedZones[zoneType] = zoneEditorServer.getModData(zoneType)
            end

            if isServer() then
                sendServerCommand("zoneEditor", "loadAll", {loadedZones=chamberedZones})
            else
                zoneEditor.loadedZones = chamberedZones
            end
        end
    end

    --sendClientCommand("zoneEditor", "loadZone", {zoneType=zoneType})
    if _command == "loadZone" then
        local zoneType = _data.zoneType
        local zones = zoneEditorServer.getModData(zoneType)

        local disableRefresh = _data.disableRefresh
        zoneEditorServer.pushUpdate(zoneType, zones, disableRefresh)
    end


    --sendClientCommand("zoneEditor", "addZone", {zoneType=selected, newZone=newZone})
    if _command == "addZone" then
        local zoneType = _data.zoneType
        local zones = zoneEditorServer.getModData(zoneType)
        local newZone = _data.newZone
        table.insert(zones, newZone)
        zoneEditorServer.pushUpdate(zoneType, zones)
    end


    --sendClientCommand("zoneEditor", "removeZone", {zoneType=selected,selected=self.zoneList.selected})
    if _command == "removeZone" then
        local zoneType = _data.zoneType
        local zones = zoneEditorServer.getModData(zoneType)
        local remove = _data.selected
        table.remove(zones, remove)
        zoneEditorServer.pushUpdate(zoneType, zones)
    end

    --sendClientCommand("zoneEditor", "editZoneData", {zoneType=zoneType,selected=zoneSelected,parentParam=parentParam,newKey=newKey,newValue=newValue})
    if _command == "editZoneData" then
        local zoneType = _data.zoneType
        local zones = zoneEditorServer.getModData(zoneType)
        local dataSelected = _data.selected
        local selectedZone = zones[dataSelected]
        local parentParam = _data.parentParam
        local newKey = _data.newKey
        local newValue = _data.newValue
        local modifying = parentParam and selectedZone[parentParam] or selectedZone
        modifying[newKey] = newValue

        zoneEditorServer.pushUpdate(zoneType, zones)
    end

    --"importZoneData", {zoneType=zoneType,zones=totalStr})
    if _command == "importZoneData" then
        local zoneType = _data.zoneType
        local newZones = _data.zones
        local zones = zoneEditorServer.getModData(zoneType)
        zones = newZones
        zoneEditorServer.pushUpdate(zoneType, zones)
    end
end


return zoneEditorServer