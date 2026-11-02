require "ISUI/AdminPanel/ZoneEditor/ISMultiplayerZoneEditor"
require "ZoneEditor/MultiplayerZoneEditorMode_ZoneAPI"
require "zoneEditor"

local MODE_PREFIX = "ZoneAPI:"


function zoneEditor.getModeKey(zoneType) return MODE_PREFIX..zoneType end


function zoneEditor.ensureEditorModes(editor)
    editor.mode = editor.mode or {}
    local added = false
    for _,zoneType in ipairs(zoneEditor.zoneTypeOrder) do
        local key = zoneEditor.getModeKey(zoneType)
        if not editor.mode[key] then
            local mode = MultiplayerZoneEditorMode_ZoneAPI:new(editor, zoneType)
            editor:addChild(mode)
            mode:setVisible(false)
            editor.mode[key] = mode
            added = true
        end
    end
    --keep the zoom/close buttons above the modes
    if added and editor.buttonPanel then
        editor:removeChild(editor.buttonPanel)
        editor:addChild(editor.buttonPanel)
    end
end


---players have no role in single player, the vanilla NonPVP/Safehouse modes index it while being built
local ISMultiplayerZoneEditor_createChildren = ISMultiplayerZoneEditor.createChildren
function ISMultiplayerZoneEditor:createChildren()
    local player = getPlayer()
    local noRole = not (player and player:getRole())
    local NonPVP, Safehouse = MultiplayerZoneEditorMode_NonPVP, MultiplayerZoneEditorMode_Safehouse
    if noRole then
        MultiplayerZoneEditorMode_NonPVP = MultiplayerZoneEditorMode
        MultiplayerZoneEditorMode_Safehouse = MultiplayerZoneEditorMode
    end
    ISMultiplayerZoneEditor_createChildren(self)
    MultiplayerZoneEditorMode_NonPVP, MultiplayerZoneEditorMode_Safehouse = NonPVP, Safehouse
    zoneEditor.ensureEditorModes(self)
end


local ISMultiplayerZoneEditor_ShowEditor = ISMultiplayerZoneEditor.ShowEditor
function ISMultiplayerZoneEditor.ShowEditor()
    ISMultiplayerZoneEditor_ShowEditor()
    local instance = ISMultiplayerZoneEditor_instance
    local player = getPlayer()
    if not instance or not player then return end
    instance.character = player
    instance.mapAPI:centerOn(player:getX(), player:getY())
    instance.mapAPI:setZoom(18.0)
end


local ISMultiplayerZoneEditor_close = ISMultiplayerZoneEditor.close
function ISMultiplayerZoneEditor:close()
    if self.currentMode and self.mode[self.currentMode] then return ISMultiplayerZoneEditor_close(self) end
    self:setVisible(false)
    self:removeFromUIManager()
    getWorld():setDrawWorld(true)
end


Events.OnRolesReceived.Remove(ISMultiplayerZoneEditor.OnRolesReceived)
function ISMultiplayerZoneEditor.OnRolesReceived()
    local instance = ISMultiplayerZoneEditor_instance
    local player = getPlayer()
    if not instance or not player then return end
    zoneEditor.ensureEditorModes(instance)

    local role = player:getRole()
    local available = {}
    instance.modeCombo:clear()

    local function addMode(text, key)
        instance.modeCombo:addOptionWithData(text, key)
        available[key] = true
        available[#available+1] = key
    end

    if role and role:hasCapability(Capability.CanSetupNonPVPZone) then addMode(getText("IGUI_MultiplayerZoneEditor_Mode_NonPVP"), "NonPVP") end
    if role and role:hasCapability(Capability.CanSetupSafehouses) then addMode(getText("IGUI_MultiplayerZoneEditor_Mode_Safehouse"), "Safehouse") end
    for _,zoneType in ipairs(zoneEditor.zoneTypeOrder) do
        if zoneEditor.canEdit(player, zoneType) then addMode(getText("IGUI_ZoneAPI_Mode", zoneEditor.getDisplayName(zoneType)), zoneEditor.getModeKey(zoneType)) end
    end

    if #available == 0 then instance:close() return end

    local target = instance.requestedMode
    instance.requestedMode = nil
    if not (target and available[target]) then target = (instance.currentMode and available[instance.currentMode]) and instance.currentMode or available[1] end

    instance.modeCombo:selectData(target)
    if target ~= instance.currentMode then instance:onSwitchMode(target) end
end
Events.OnRolesReceived.Add(function() ISMultiplayerZoneEditor.OnRolesReceived() end)


---Opens the vanilla zone editor on a zone type (first editable one if not given).
function zoneEditor.OnOpenPanel(zoneType)
    local player = getPlayer()
    if not player or not zoneEditor.canEdit(player) then return end

    if not (zoneType and zoneEditor.zoneTypes[zoneType] and zoneEditor.canEdit(player, zoneType)) then
        zoneType = nil
        for _,t in ipairs(zoneEditor.zoneTypeOrder) do
            if zoneEditor.canEdit(player, t) then zoneType = t break end
        end
    end
    local key = zoneEditor.getModeKey(zoneType)

    if ISMultiplayerZoneEditor_instance then ISMultiplayerZoneEditor_instance.requestedMode = key end
    ISMultiplayerZoneEditor.ShowEditor()

    local instance = ISMultiplayerZoneEditor_instance
    if instance.currentMode ~= key and instance.mode[key] then
        instance.modeCombo:selectData(key)
        instance:onSwitchMode(key)
    end
    return instance
end
