require "zoneEditor"

local zoneEditorClient = {}

function zoneEditorClient.onServerCommand(_module, _command, _data)
    if _module ~= "zoneEditor" then return end
    _data = _data or {}

    if _command == "loadZone" then
        local zoneType = _data.zoneType
        local zones = _data.zones
        local disableRefresh = _data.disableRefresh

        zoneEditor.loadedZones[zoneType] = zones
        if (not disableRefresh) and zoneEditor.instance then zoneEditor.instance.refresh = 1 end
    end

end
Events.OnServerCommand.Add(zoneEditorClient.onServerCommand)

return zoneEditorClient