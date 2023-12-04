if not isClient() then require "zoneEditor" end

local zoneEditorServer = {}

function zoneEditorServer.pushUpdate(zoneType, zones, disableRefresh)
    if isServer() then
        sendServerCommand("zoneEditor", "loadZone", {zoneType=zoneType, zones=zones, disableRefresh=disableRefresh})
    else
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
                local modDataID = zoneType.."_zones"
                chamberedZones[zoneType] = ModData.getOrCreate(modDataID)
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
        local zones = ModData.getOrCreate(zoneType.."_zones")
        local disableRefresh = _data.disableRefresh
        zoneEditorServer.pushUpdate(zoneType, zones, disableRefresh)
    end


    --sendClientCommand("zoneEditor", "addZone", {zoneType=selected, newZone=newZone})
    if _command == "addZone" then
        local zoneType = _data.zoneType
        local zones = ModData.getOrCreate(zoneType.."_zones")
        local newZone = _data.newZone

        table.insert(zones, newZone)
        zoneEditorServer.pushUpdate(zoneType, zones)
    end


    --sendClientCommand("zoneEditor", "removeZone", {zoneType=selected,selected=self.zoneList.selected})
    if _command == "removeZone" then
        local zoneType = _data.zoneType
        local zones = ModData.getOrCreate(zoneType.."_zones")
        local remove = _data.selected
        print("zoneType: ", zoneType, ",   remove: ",remove)
        table.remove(zones, remove)
        zoneEditorServer.pushUpdate(zoneType, zones)
    end

    --sendClientCommand("zoneEditor", "editZoneData", {zoneType=zoneType,selected=zoneSelected,parentParam=parentParam,newKey=newKey,newValue=newValue})
    if _command == "editZoneData" then

        local zoneType = _data.zoneType
        local zones = ModData.getOrCreate(zoneType.."_zones")
        local selected = zones[_data.selected]
        local parentParam = _data.parentParam
        local newKey = _data.newKey
        local newValue = _data.newValue
        local modifying = parentParam and selected[parentParam] or selected
        modifying[newKey] = newValue

        zoneEditorServer.pushUpdate(zoneType, zones, true)
    end
end


return zoneEditorServer