local zoneEditorServer = {}

function zoneEditorServer.receiveGlobalModData(name, data)
    ModData.add(name, data)
    ModData.transmit(name)
end

function zoneEditorServer.onClientCommand(_module, _command, _player, _data)
    if _module ~= "zoneEditor" then return end
    _data = _data or {}

    --sendClientCommand("zoneEditor", "addZoneTypeToServer", {zoneTypes=})
    if _command == "addZoneTypesToServer" then
        for _,zoneType in pairs(_data.zoneTypes) do
            ModData.getOrCreate(zoneType.."_zones")
            ModData.transmit(zoneType.."_zones")
        end
    end

    --sendClientCommand("zoneEditor", "sendZoneData", {zoneType=,zones=})
    if _command == "sendZoneData" then
        local zoneType = _data.zoneType
        ModData.add(zoneType.."_zones", _data.zones)
        ModData.transmit(zoneType.."_zones")
    end
end


return zoneEditorServer