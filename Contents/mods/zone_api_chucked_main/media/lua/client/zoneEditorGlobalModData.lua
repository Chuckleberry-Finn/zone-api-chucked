require "zoneEditor"

local function initGlobalModData(isNewGame)
    if not isClient() then
        for zoneType,zoneData in pairs(zoneEditor.zoneTypes) do
            local modDataID = zoneType.."_zones"
            zoneEditor.loadedZones[zoneType] = ModData.getOrCreate(modDataID)
        end
    else
        sendClientCommand("zoneEditor", "loadAll", {zoneTypes=zoneEditor.zoneTypes})
    end
end
Events.OnInitGlobalModData.Add(initGlobalModData)