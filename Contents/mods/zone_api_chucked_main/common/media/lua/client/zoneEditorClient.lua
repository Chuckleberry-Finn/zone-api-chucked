require "zoneEditor"

local zoneEditorClient = {}


function zoneEditorClient.onServerCommand(_module, _command, _data)
    if _module ~= zoneEditor.MODULE then return end
    _data = _data or {}

    if _command == "loadAll" then
        for zoneType,zones in pairs(_data.loadedZones or {}) do zoneEditor.setZones(zoneType, zones) end
    end

    if _command == "loadZone" then
        if not _data.zoneType then return end
        zoneEditor.setZones(_data.zoneType, _data.zones or {})
    end
end
Events.OnServerCommand.Add(zoneEditorClient.onServerCommand)


function zoneEditorClient.requestAll()
    if not isClient() then return end
    sendClientCommand(getPlayer(), zoneEditor.MODULE, "loadAll", {zoneTypes=zoneEditor.zoneTypeOrder})
end
Events.OnGameStart.Add(zoneEditorClient.requestAll)


require "DebugUIs/DebugMenu/ISDebugMenu"
local ISDebugMenu_setupButtons = ISDebugMenu.setupButtons
function ISDebugMenu:setupButtons()
    self:addButtonInfo(getText("IGUI_AdminPanel_ZoneEditor"), function() zoneEditor.OnOpenPanel() end, "MAIN")
    ISDebugMenu_setupButtons(self)
end


require "ISUI/AdminPanel/ISAdminPanelUI"
local ISAdminPanelUI_updateButtons = ISAdminPanelUI.updateButtons
function ISAdminPanelUI:updateButtons()
    ISAdminPanelUI_updateButtons(self)
    if self.zoneEditor and zoneEditor.canEdit(getPlayer()) then self.zoneEditor.enable = true end
end


return zoneEditorClient
