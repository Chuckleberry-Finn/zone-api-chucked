local zoneEditorServer = {}

zoneEditorServer.zoneTypes = {}

function zoneEditorServer.receiveGlobalModData(name, data)
    if zoneEditorServer.zoneTypes[name] and data and type(data) == "table" then
        local modDataID = name.."_zones"
        local modData = ModData.getOrCreate(modDataID)
        ModData.add(modData, data)
        ModData.transmit(modDataID,data)
    end
end

return zoneEditorServer