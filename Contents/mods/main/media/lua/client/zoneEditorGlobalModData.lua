require "zoneEditor"
local function initGlobalModData(isNewGame)
    if isClient() then
        for zoneType,zoneData in pairs(zoneEditor.zoneTypes) do
            local modDataID = zoneType.."_zones"
            if ModData.exists(modDataID) then ModData.remove(modDataID) end
            ModData.request(modDataID)
        end
    end
end
Events.OnInitGlobalModData.Add(initGlobalModData)