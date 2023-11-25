local zoneEditorServer = {}

zoneEditorServer.zoneTypes = {}

function zoneEditorServer.receiveGlobalModData(name, data)
    if zoneEditorServer.zoneTypes[name] and data and type(data) == "table" then
        local modDataID = name.."_zones"
        if ModData.exists(modDataID) then ModData.remove(modDataID) end
        ModData.add(modDataID,data)
    end
end


function zoneEditorServer.onClientCommand(_module, _command, _player, _data)
    if _module ~= "zoneEditor" then return end
    _data = _data or {}

    if _command == "addZoneTypeToServer" then
        zoneEditorServer.zoneTypes[_data.zoneType] = true
        ModData.getOrCreate(_data.zoneType.."_zones")
    end
end
--sendClientCommand("zoneEditor", "addZoneTypeToServer", {zoneType=""})

return zoneEditorServer