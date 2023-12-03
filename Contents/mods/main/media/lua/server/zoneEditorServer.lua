local zoneEditorServer = {}

function zoneEditorServer.receiveGlobalModData(name, data)
    local modData = ModData.getOrCreate(name)
    modData = data
    ModData.transmit(name,data)
end

function zoneEditorServer.onClientCommand(_module, _command, _player, _data)
    if _module ~= "zoneEditor" then return end
    _data = _data or {}

    if _command == "addZoneTypesToServer" then
        for _,zoneType in pairs(_data.zoneTypes) do ModData.getOrCreate(zoneType.."_zones") end
    end
end
--sendClientCommand("zoneEditor", "addZoneTypeToServer", {zoneType=fileName})

return zoneEditorServer