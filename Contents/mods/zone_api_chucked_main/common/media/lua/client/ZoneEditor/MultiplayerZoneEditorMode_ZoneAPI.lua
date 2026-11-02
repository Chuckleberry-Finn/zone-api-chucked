require "ISUI/AdminPanel/ZoneEditor/MultiplayerZoneEditorMode"
require "ISUI/ISCollapsableWindowJoypad"
require "ISUI/Maps/Editor/WorldMapEditorResizer"
require "zoneEditor"

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local UI_BORDER_SPACING = 10
local BUTTON_HGT = FONT_HGT_SMALL + 6
local PANEL_W = 320
local HANDLE = 8
local VANILLA_MAX_VIEW = 2400*2400
local VANILLA_MAX_DRAW = 2000

MultiplayerZoneEditorMode_ZoneAPI = MultiplayerZoneEditorMode:derive("MultiplayerZoneEditorMode_ZoneAPI")
ZoneAPIVanillaZoneOptions = ISCollapsableWindowJoypad:derive("ZoneAPIVanillaZoneOptions")


---stored coordinates are inclusive squares, the map rect ends on the far edge of the last square
local function zoneToMapRect(zone)
    local x1, y1, x2, y2 = zoneEditor.getBounds(zone)
    if not x1 then return end
    return x1, y1, x2+1, y2+1
end


local function zoneLabel(zone, i)
    local label = (zone.name and tostring(zone.name) ~= "") and tostring(zone.name) or "#"..i
    local x1, y1, x2, y2 = zoneEditor.getBounds(zone)
    if not x1 then return label.."  "..getText("IGUI_ZoneAPI_Unplaced") end
    return label.."  ("..x1..","..y1.." "..(x2-x1+1).."x"..(y2-y1+1)..")"
end


local function typeColor(str)
    local h = 0
    for i=1, #str do h = (h*31 + string.byte(str, i)) % 360 end
    local c, x = 0.48, 0.48 * (1 - math.abs((h/60) % 2 - 1))
    local r, g, b = 0, 0, 0
    if h < 60 then r,g,b = c,x,0 elseif h < 120 then r,g,b = x,c,0 elseif h < 180 then r,g,b = 0,c,x
    elseif h < 240 then r,g,b = 0,x,c elseif h < 300 then r,g,b = x,0,c else r,g,b = c,0,x end
    return r+0.32, g+0.32, b+0.32
end


local function sortedKeys(tbl)
    local keys = {}
    for k in pairs(tbl) do table.insert(keys, k) end
    table.sort(keys, function(a, b)
        if a == "name" then return true end
        if b == "name" then return false end
        return tostring(a) < tostring(b)
    end)
    return keys
end


function MultiplayerZoneEditorMode_ZoneAPI:addButton(x, y, title, func, tooltip)
    local button = ISButton:new(x, y, 60, BUTTON_HGT, title, self, func)
    button:setWidthToTitle()
    if tooltip then button:setTooltip(tooltip) end
    self:addChild(button)
    return button
end


function MultiplayerZoneEditorMode_ZoneAPI:createChildren()
    local x = UI_BORDER_SPACING
    local modeCombo = self.editor.modeCombo

    self.vanillaButton = self:addButton(modeCombo:getRight() + UI_BORDER_SPACING, modeCombo:getY(), "", self.onToggleVanillaList)

    local y = modeCombo:getBottom() + UI_BORDER_SPACING

    self.listbox = ISScrollingListBox:new(x, y, PANEL_W, (FONT_HGT_SMALL + 3*2) * 8)
    self.listbox:setFont(UIFont.Small, 3)
    self.listbox.drawBorder = true
    self.listbox:setOnMouseDownFunction(self, self.onListSelect)
    self:addChild(self.listbox)
    y = self.listbox:getBottom() + UI_BORDER_SPACING

    self.addZoneButton = self:addButton(x, y, getText("IGUI_MultiplayerZoneEditor_Button_AddZone"), self.onAddZone, getText("IGUI_ZoneAPI_AddZone_Tooltip"))
    self.duplicateButton = self:addButton(self.addZoneButton:getRight()+6, y, getText("IGUI_ZoneAPI_Duplicate"), self.onDuplicateZone)
    self.removeButton = self:addButton(self.duplicateButton:getRight()+6, y, getText("IGUI_MultiplayerZoneEditor_Button_RemoveZone"), self.onRemoveZone)
    y = self.addZoneButton:getBottom() + UI_BORDER_SPACING

    self.snapCombo = ISComboBox:new(x, y, 140, BUTTON_HGT, self, self.onSnapChanged)
    self.snapCombo:addOptionWithData(getText("IGUI_ZoneAPI_Snap_Square"), "square")
    self.snapCombo:addOptionWithData(getText("IGUI_ZoneAPI_Snap_Chunk"), "chunk")
    self.snapCombo:addOptionWithData(getText("IGUI_ZoneAPI_Snap_Cell"), "cell")
    self:addChild(self.snapCombo)
    y = self.snapCombo:getBottom() + UI_BORDER_SPACING

    self.propertyList = ISScrollingListBox:new(x, y, PANEL_W, (FONT_HGT_SMALL + 2*2) * 12)
    self.propertyList:setFont(UIFont.Small, 2)
    self.propertyList.drawBorder = true
    self.propertyList:setOnMouseDoubleClick(self, self.onEditProperty)
    self:addChild(self.propertyList)
    self.propertyHintY = self.propertyList:getBottom() + 4
    y = self.propertyHintY + FONT_HGT_SMALL + UI_BORDER_SPACING

    self.exportButton = self:addButton(x, y, getText("IGUI_ZoneAPI_Export"), self.onExport, getText("IGUI_EXPORT_ZONE"))
    self.importButton = self:addButton(self.exportButton:getRight()+6, y, getText("IGUI_ZoneAPI_Import"), self.onImport, getText("IGUI_IMPORT_ZONE"))
    self.infoY = self.exportButton:getBottom() + UI_BORDER_SPACING
    self:updateVanillaShown()
end


function MultiplayerZoneEditorMode_ZoneAPI:getZones() return zoneEditor.loadedZones[self.zoneType] end


function MultiplayerZoneEditorMode_ZoneAPI:getSelectedZone()
    local zones = self:getZones()
    return zones and self.selectedIndex and zones[self.selectedIndex]
end


function MultiplayerZoneEditorMode_ZoneAPI:send(command, args)
    args.zoneType = self.zoneType
    sendClientCommand(getPlayer(), zoneEditor.MODULE, command, args)
end


function MultiplayerZoneEditorMode_ZoneAPI:fillList()
    local zones = self:getZones()
    if self.delaySelectIndex and zones and zones[self.delaySelectIndex] then
        self.selectedIndex = self.delaySelectIndex
        self.delaySelectIndex = nil
    end
    if self.selectedIndex and not (zones and zones[self.selectedIndex]) then self.selectedIndex = nil end

    local yScroll = self.listbox:getYScroll()
    self.listbox:clear()
    if zones then
        for i,zone in ipairs(zones) do self.listbox:addItem(zoneLabel(zone, i), i) end
    end
    self.listbox.selected = self.selectedIndex or 0
    self.listbox:setYScroll(yScroll)
end


function MultiplayerZoneEditorMode_ZoneAPI:onListSelect(index)
    if self.mode then return end
    self.selectedIndex = index
    local x1, y1, x2, y2 = zoneToMapRect(self:getSelectedZone())
    if x1 then self.mapAPI:centerOn((x1+x2)/2, (y1+y2)/2) end
end


function MultiplayerZoneEditorMode_ZoneAPI:fillProperties()
    local yScroll = self.propertyList:getYScroll()
    local selected = self.propertyList.selected
    self.propertyList:clear()

    local zone = self:getSelectedZone()
    if not zone then return end

    local module = zoneEditor.zoneTypes[self.zoneType]
    local tooltips = module and module.tooltips

    for _,key in ipairs(sortedKeys(zone)) do
        if not zoneEditor.ignore[key] then
            local value = zone[key]
            local tooltip = tooltips and tooltips[key] or nil
            if type(value) == "table" then
                self.propertyList:addItem(tostring(key)..":", nil, tooltip)
                for _,subKey in ipairs(sortedKeys(value)) do
                    if type(value[subKey]) ~= "table" then
                        self.propertyList:addItem("     "..tostring(subKey).." = "..tostring(value[subKey]), {parent=key, key=subKey}, tooltip)
                    end
                end
            else
                self.propertyList:addItem(tostring(key).." = "..tostring(value), {key=key}, tooltip)
            end
        end
    end

    self.propertyList.selected = math.min(selected, #self.propertyList.items)
    self.propertyList:setYScroll(yScroll)
end


function MultiplayerZoneEditorMode_ZoneAPI:onEditProperty(item)
    local zone = self:getSelectedZone()
    if not zone or not item or item.key == nil then return end
    local current = item.parent and zone[item.parent][item.key] or zone[item.key]
    local title = getText("IGUI_ZoneAPI_EditValue", item.parent and tostring(item.parent).."."..tostring(item.key) or tostring(item.key))

    self:closeModal()
    local modal = ISTextBox:new(self.propertyList:getRight()+20, self.propertyList:getY(), 300, 160, title, tostring(current), self, self.onPropertyEntered)
    modal:initialise()
    modal:addToUIManager()
    modal:setAlwaysOnTop(true)
    modal.zoneIndex = self.selectedIndex
    modal.item = item
    modal.oldValue = current
    self.modalUI = modal
end


function MultiplayerZoneEditorMode_ZoneAPI:onPropertyEntered(button)
    self.modalUI = nil
    if button.internal ~= "OK" then return end
    local modal = button.parent
    local oldValue = modal.oldValue
    local newValue = modal.entry:getText()

    if type(oldValue) == "number" then newValue = tonumber(newValue)
    elseif type(oldValue) == "boolean" then newValue = (newValue == "true" and true) or (newValue == "false" and false) or nil
    elseif (oldValue == "true" or oldValue == "false") and newValue ~= "true" and newValue ~= "false" then newValue = nil
    end
    if newValue == nil or newValue == "" then return end

    self:send("editZoneData", {selected=modal.zoneIndex, parentParam=modal.item.parent, newKey=modal.item.key, newValue=newValue})
end


function MultiplayerZoneEditorMode_ZoneAPI:prerender()
    MultiplayerZoneEditorMode.prerender(self)
    self:fillList()

    local zone = self:getSelectedZone()
    if not self.mode then
        local x1, y1, x2, y2 = zoneToMapRect(zone)
        local key = zone and self.selectedIndex..":"..tostring(zone.name)..":"..tostring(x1)..","..tostring(y1)..","..tostring(x2)..","..tostring(y2)
        if key ~= self.lastSelectedKey then
            self.lastSelectedKey = key
            if x1 then self.resizer:setBounds(x1, y1, x2, y2) else self.resizer:setBounds(0, 0, 0, 0) end
            self.propertiesDirty = true
        end
    end
    if self.propertiesDirty then
        self.propertiesDirty = false
        self:fillProperties()
    end

    local canEdit = zoneEditor.canEdit(getPlayer(), self.zoneType)
    self.addZoneButton:setEnable(canEdit)
    self.importButton:setEnable(canEdit)
    self.duplicateButton:setEnable(canEdit and zone ~= nil)
    self.removeButton:setEnable(canEdit and zone ~= nil)
end


function MultiplayerZoneEditorMode_ZoneAPI:worldRectToUI(x1, y1, x2, y2)
    local ux1, uy1 = self.mapAPI:worldToUIX(x1, y1), self.mapAPI:worldToUIY(x1, y1)
    local ux2, uy2 = self.mapAPI:worldToUIX(x2, y2), self.mapAPI:worldToUIY(x2, y2)
    return math.min(ux1,ux2), math.min(uy1,uy2), math.max(ux1,ux2), math.max(uy1,uy2)
end


function MultiplayerZoneEditorMode_ZoneAPI:drawWorldLine(x1, y1, x2, y2, r, g, b, a)
    local ux1, uy1 = self.mapAPI:worldToUIX(x1, y1), self.mapAPI:worldToUIY(x1, y1)
    local ux2, uy2 = self.mapAPI:worldToUIX(x2, y2), self.mapAPI:worldToUIY(x2, y2)
    self.mapUI.javaObject:DrawLine(Texture:getWhite(), ux1, uy1, ux2, uy2, 1, r, g, b, a)
end


function MultiplayerZoneEditorMode_ZoneAPI:mouseWorld()
    local mx, my = self.mapUI:getMouseX(), self.mapUI:getMouseY()
    return self.mapAPI:uiToWorldX(mx, my), self.mapAPI:uiToWorldY(mx, my)
end


function MultiplayerZoneEditorMode_ZoneAPI:mouseWorldSnapped()
    local wx, wy = self:mouseWorld()
    return self.resizer:snap(wx), self.resizer:snap(wy)
end


function MultiplayerZoneEditorMode_ZoneAPI:getVanillaZonesInView()
    local w, h = self.mapUI:getWidth(), self.mapUI:getHeight()
    local ax, ay = self.mapAPI:uiToWorldX(0, 0), self.mapAPI:uiToWorldY(0, 0)
    local bx, by = self.mapAPI:uiToWorldX(w, h), self.mapAPI:uiToWorldY(w, h)
    local x1, y1 = math.floor(math.min(ax,bx)), math.floor(math.min(ay,by))
    local x2, y2 = math.ceil(math.max(ax,bx)), math.ceil(math.max(ay,by))
    if (x2-x1)*(y2-y1) > VANILLA_MAX_VIEW then return end

    local key = x1..","..y1..","..x2..","..y2
    if self.vanillaCacheKey ~= key then
        self.vanillaCacheKey = key
        self.vanillaCache = getWorld():getMetaGrid():getZonesIntersecting(x1, y1, 0, x2-x1, y2-y1)
    end
    return self.vanillaCache
end


function MultiplayerZoneEditorMode_ZoneAPI:showsVanillaType(zoneType)
    return self.vanillaShown[zoneType]
end


function MultiplayerZoneEditorMode_ZoneAPI:renderVanillaZone(vZone)
    local r, g, b = typeColor(tostring(vZone:getType()))
    if vZone:isPolygon() or vZone:isPolyline() then
        local points = vZone:getPointsToLua()
        local n = points:size()
        if n < 4 then return end
        for i=0, n-4, 2 do self:drawWorldLine(points:get(i), points:get(i+1), points:get(i+2), points:get(i+3), r, g, b, 0.8) end
        if vZone:isPolygon() then self:drawWorldLine(points:get(n-2), points:get(n-1), points:get(0), points:get(1), r, g, b, 0.8) end
        return
    end
    local ux1, uy1, ux2, uy2 = self:worldRectToUI(vZone:getX(), vZone:getY(), vZone:getX()+vZone:getWidth(), vZone:getY()+vZone:getHeight())
    self.mapUI:drawRectBorder(ux1, uy1, ux2-ux1, uy2-uy1, 0.8, r, g, b)
    if ux2-ux1 > 60 and uy2-uy1 > FONT_HGT_SMALL*2 then
        self.mapUI:drawText(tostring(vZone:getType()), ux1+3, uy1+2, r*0.5, g*0.5, b*0.5, 1, UIFont.Small)
    end
end


function MultiplayerZoneEditorMode_ZoneAPI:render()
    MultiplayerZoneEditorMode.render(self)

    self.vanillaTooFar = false
    if self.vanillaShownCount > 0 then
        local list = self:getVanillaZonesInView()
        if list then
            local drawn = 0
            for i=0, list:size()-1 do
                local vZone = list:get(i)
                if self:showsVanillaType(vZone:getType()) then
                    self:renderVanillaZone(vZone)
                    drawn = drawn + 1
                    if drawn >= VANILLA_MAX_DRAW then break end
                end
            end
        else
            self.vanillaTooFar = true
        end
    end

    local zones = self:getZones()
    if zones then
        for i,zone in ipairs(zones) do
            local x1, y1, x2, y2 = zoneToMapRect(zone)
            if x1 and not (i == self.selectedIndex and self.mode) then
                local ux1, uy1, ux2, uy2 = self:worldRectToUI(x1, y1, x2, y2)
                local w, h = math.max(1, ux2-ux1), math.max(1, uy2-uy1)
                self.mapUI:drawRect(ux1, uy1, w, h, (i == self.selectedIndex) and 0.35 or 0.2, self.zoneR, self.zoneG, self.zoneB)
                self.mapUI:drawRectBorder(ux1, uy1, w, h, 0.9, self.zoneR, self.zoneG, self.zoneB)
                if w > 40 then self.mapUI:drawText(zone.name and tostring(zone.name) or "#"..i, ux1+4, uy1+2, 0, 0, 0, 1, UIFont.Small) end
            end
        end
    end

    local resizer = self.resizer
    if (self:getSelectedZone() or self.mode == "DrawBounds") and resizer.x2 > resizer.x1 then
        if self.mode then
            local ux1, uy1, ux2, uy2 = self:worldRectToUI(resizer.x1, resizer.y1, resizer.x2, resizer.y2)
            self.mapUI:drawRect(ux1, uy1, ux2-ux1, uy2-uy1, 0.35, self.zoneR, self.zoneG, self.zoneB)
        end
        resizer:render(0, 0, 0, 1)
        if self.mode ~= "DrawBounds" then self:renderMoveHandle() end
    end

    if self.mode == "StartDrawingBounds" then
        local wx, wy = self:mouseWorldSnapped()
        local mx, my = self.mapAPI:worldToUIX(wx, wy), self.mapAPI:worldToUIY(wx, wy)
        self.mapUI:drawRectBorder(mx-10, my-10, 20, 20, 1, 0, 0, 1)
        self.mapUI:drawRectBorder(mx-11, my-11, 22, 22, 1, 0, 0, 1)
    end

    self:renderInfo()
end


function MultiplayerZoneEditorMode_ZoneAPI:getMoveHandleUI()
    local cx, cy = (self.resizer.x1+self.resizer.x2)/2, (self.resizer.y1+self.resizer.y2)/2
    return self.mapAPI:worldToUIX(cx, cy), self.mapAPI:worldToUIY(cx, cy)
end


function MultiplayerZoneEditorMode_ZoneAPI:hitTestMoveHandle(x, y)
    if not self:getSelectedZone() then return false end
    local hx, hy = self:getMoveHandleUI()
    return math.abs(x-hx) <= HANDLE+2 and math.abs(y-hy) <= HANDLE+2
end


function MultiplayerZoneEditorMode_ZoneAPI:renderMoveHandle()
    local hx, hy = self:getMoveHandleUI()
    local hot = self.mode == "Move" or self:hitTestMoveHandle(self.mapUI:getMouseX(), self.mapUI:getMouseY())
    self.mapUI:drawRect(hx-HANDLE, hy-HANDLE, HANDLE*2, HANDLE*2, 0.8, 1, 1, 1)
    self.mapUI:drawRectBorder(hx-HANDLE, hy-HANDLE, HANDLE*2, HANDLE*2, 1, hot and 1 or 0, 0, 0)
end


function MultiplayerZoneEditorMode_ZoneAPI:renderInfo()
    local wx, wy = self:mouseWorld()
    wx, wy = math.floor(wx), math.floor(wy)
    local lines = {"x: "..wx..", y: "..wy}

    local here = {}
    for _,zone in ipairs(zoneEditor.getZonesAt(self.zoneType, wx, wy)) do table.insert(here, tostring(zone.name)) end
    if #here > 0 then table.insert(lines, zoneEditor.getDisplayName(self.zoneType)..": "..table.concat(here, ", ")) end

    if self.vanillaShownCount > 0 then
        local vZones = getWorld():getMetaGrid():getZonesAt(wx, wy, 0)
        local types = {}
        for i=0, vZones:size()-1 do
            local vZone = vZones:get(i)
            local name = vZone:getName()
            if self:showsVanillaType(vZone:getType()) then table.insert(types, tostring(vZone:getType())..((name and name ~= "") and " ("..name..")" or "")) end
        end
        if #types > 0 then table.insert(lines, getText("IGUI_ZoneAPI_VanillaHere")..": "..table.concat(types, ", ")) end
        if self.vanillaTooFar then table.insert(lines, getText("IGUI_ZoneAPI_ZoomInVanilla")) end
    end

    if self.mode == "StartDrawingBounds" then table.insert(lines, getText("IGUI_ZoneAPI_Hint_Draw"))
    elseif self:getSelectedZone() and not self.mode then table.insert(lines, getText("IGUI_ZoneAPI_Hint_Selected"))
    end

    local x, y = UI_BORDER_SPACING, self.infoY
    local width = 0
    for _,line in ipairs(lines) do width = math.max(width, getTextManager():MeasureStringX(UIFont.Small, line)) end
    self:drawRect(x-4, y-2, width+8, #lines*FONT_HGT_SMALL+4, 0.75, 0, 0, 0)
    for i,line in ipairs(lines) do self:drawText(line, x, y+(i-1)*FONT_HGT_SMALL, 1, 1, 1, 1, UIFont.Small) end

    local hint = self:getSelectedZone() and getText("IGUI_ZoneAPI_DoubleClickEdit") or getText("IGUI_ZoneAPI_SelectZone")
    self:drawText(hint, x, self.propertyHintY, 0.1, 0.1, 0.1, 1, UIFont.Small)
end


function MultiplayerZoneEditorMode_ZoneAPI:zoneIndexAt(x, y)
    local zones = self:getZones()
    if not zones then return end
    local wx, wy = self.mapAPI:uiToWorldX(x, y), self.mapAPI:uiToWorldY(x, y)
    local best, bestArea
    for i,zone in ipairs(zones) do
        local x1, y1, x2, y2 = zoneToMapRect(zone)
        if x1 and wx >= x1 and wx < x2 and wy >= y1 and wy < y2 then
            local area = (x2-x1)*(y2-y1)
            if not bestArea or area < bestArea then best, bestArea = i, area end
        end
    end
    return best
end


function MultiplayerZoneEditorMode_ZoneAPI:onMouseDown(x, y)
    self.clickCandidate = nil

    if self.mode == "StartDrawingBounds" then
        self.mode = "DrawBounds"
        local wx, wy = self:mouseWorldSnapped()
        self.resizer:setBounds(wx, wy, wx, wy)
        self.resizer:startResizing()
        return true
    end

    if self:getSelectedZone() and zoneEditor.canEdit(getPlayer(), self.zoneType) then
        if self:hitTestMoveHandle(x, y) then
            self.mode = "Move"
            self.resizer:startResizing()
            self.moveStartX, self.moveStartY = self:mouseWorldSnapped()
            return true
        end
        local resizeMode = self.resizer:hitTest(x, y)
        if resizeMode then
            self.mode = "Resize"
            self.resizeMode = resizeMode
            self.resizer:startResizing()
            return true
        end
    end

    --a click (not a drag) selects the zone under the mouse, dragging still pans the map
    self.clickCandidate = {x=x, y=y, index=self:zoneIndexAt(x, y)}
    return false
end


function MultiplayerZoneEditorMode_ZoneAPI:onMouseMove(dx, dy)
    local mx, my = self:getMouseX(), self:getMouseY()
    if self.mode == "DrawBounds" then
        self.resizer:onMouseMove(mx, my, "BottomRight")
    elseif self.mode == "Resize" then
        self.resizer:onMouseMove(mx, my, self.resizeMode)
    elseif self.mode == "Move" then
        local wx, wy = self:mouseWorldSnapped()
        local b = self.resizer.originalBounds
        local ox, oy = wx-self.moveStartX, wy-self.moveStartY
        self.resizer:setBounds(b.x1+ox, b.y1+oy, b.x2+ox, b.y2+oy)
    end
    return self.mode ~= nil
end


function MultiplayerZoneEditorMode_ZoneAPI:onMouseMoveOutside(dx, dy) return self:onMouseMove(dx, dy) end


function MultiplayerZoneEditorMode_ZoneAPI:onMouseUp(x, y)
    local r = self.resizer

    if self.mode == "DrawBounds" then
        self.mode = nil
        r:endResizing()
        if r.x1 < r.x2 and r.y1 < r.y2 then self:promptNewZone(r.x1, r.y1, r.x2, r.y2) end
        self.lastSelectedKey = nil
        return true
    end

    if self.mode == "Resize" or self.mode == "Move" then
        self.mode = nil
        self.resizeMode = nil
        r:endResizing()
        if r.x1 < r.x2 and r.y1 < r.y2 then
            self:send("setBounds", {selected=self.selectedIndex, x1=r.x1, y1=r.y1, x2=r.x2-1, y2=r.y2-1})
        else
            r:cancelResize()
        end
        return true
    end

    local click = self.clickCandidate
    self.clickCandidate = nil
    if click and math.abs(x-click.x) <= 4 and math.abs(y-click.y) <= 4 then self.selectedIndex = click.index end
    return false
end


function MultiplayerZoneEditorMode_ZoneAPI:onMouseUpOutside(x, y)
    if self.mode then return self:onMouseUp(x, y) end
    self.clickCandidate = nil
    return false
end


function MultiplayerZoneEditorMode_ZoneAPI:onRightMouseDown(x, y) return self:cancelAction() end


function MultiplayerZoneEditorMode_ZoneAPI:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE then return self:cancelAction() end
    if key == Keyboard.KEY_DELETE and self:getSelectedZone() and not self.mode and not self.modalUI then
        self:onRemoveZone()
        return true
    end
    return false
end


function MultiplayerZoneEditorMode_ZoneAPI:cancelAction()
    if not self.mode then return false end
    if self.mode == "DrawBounds" or self.mode == "Resize" or self.mode == "Move" then self.resizer:cancelResize() end
    self.mode = nil
    self.resizeMode = nil
    self.lastSelectedKey = nil
    return true
end


function MultiplayerZoneEditorMode_ZoneAPI:onAddZone()
    local wasDrawing = self.mode == "StartDrawingBounds"
    self:cancelAction()
    if not wasDrawing then self.mode = "StartDrawingBounds" end
end


function MultiplayerZoneEditorMode_ZoneAPI:newZoneFromTemplate()
    local module = zoneEditor.zoneTypes[self.zoneType]
    return module and module.Zone and copyTable(module.Zone)
end


---x2, y2 are map coordinates (far edge)
function MultiplayerZoneEditorMode_ZoneAPI:promptNewZone(x1, y1, x2, y2, defaultName)
    local template = self:newZoneFromTemplate()
    if not template then return end
    self:closeModal()
    local modal = ISTextBox:new(0, 0, 280, 180, getText("IGUI_PvpZone_RenamePrompt"), tostring(defaultName or template.name or "newZone"), self, self.onNewZoneNameEntered)
    modal:initialise()
    modal:addToUIManager()
    modal:setAlwaysOnTop(true)
    modal.coordinates = {x1=math.floor(x1), y1=math.floor(y1), x2=math.floor(x2)-1, y2=math.floor(y2)-1}
    self.modalUI = modal
end


function MultiplayerZoneEditorMode_ZoneAPI:onNewZoneNameEntered(button)
    self.modalUI = nil
    if button.internal ~= "OK" then return end
    local newZone = self:newZoneFromTemplate()
    if not newZone then return end
    local name = button.parent.entry:getText()
    if name and name ~= "" then newZone.name = name end
    newZone.coordinates = button.parent.coordinates
    local zones = self:getZones()
    self.delaySelectIndex = (zones and #zones or 0) + 1
    self:send("addZone", {newZone=newZone})
end


function MultiplayerZoneEditorMode_ZoneAPI:onDuplicateZone()
    local zone = self:getSelectedZone()
    if not zone then return end
    local newZone = copyTable(zone)
    newZone.name = tostring(zone.name or "zone").." copy"
    local zones = self:getZones()
    self.delaySelectIndex = (zones and #zones or 0) + 1
    self:send("addZone", {newZone=newZone})
end


function MultiplayerZoneEditorMode_ZoneAPI:onRemoveZone()
    local zone = self:getSelectedZone()
    if not zone then return end
    self:closeModal()
    local text = getText("IGUI_PvpZone_RemoveConfirm", tostring(zone.name or "#"..self.selectedIndex))
    local modal = ISModalDialog:new(self.removeButton:getRight()+20, self.removeButton:getY(), 350, 150, text, true, self, self.onConfirmRemoveZone)
    modal:initialise()
    modal:addToUIManager()
    modal.moveWithMouse = true
    modal:setAlwaysOnTop(true)
    modal.zoneIndex = self.selectedIndex
    self.modalUI = modal
end


function MultiplayerZoneEditorMode_ZoneAPI:onConfirmRemoveZone(button)
    self.modalUI = nil
    if button.internal ~= "YES" then return end
    local index = button.parent.zoneIndex
    if self.selectedIndex == index then self.selectedIndex = nil end
    self:send("removeZone", {selected=index})
end


function MultiplayerZoneEditorMode_ZoneAPI:onSnapChanged()
    self.resizer.snapMode = self.snapCombo:getOptionData(self.snapCombo.selected) or "square"
end


function MultiplayerZoneEditorMode_ZoneAPI.getVanillaZoneTypes()
    if MultiplayerZoneEditorMode_ZoneAPI.vanillaZoneTypes then return MultiplayerZoneEditorMode_ZoneAPI.vanillaZoneTypes end
    local found, types = {}, {}
    local zones = getWorld():getMetaGrid():getZones()
    for i=0, zones:size()-1 do
        local zoneType = zones:get(i):getType()
        if zoneType and zoneType ~= "" and not found[zoneType] then
            found[zoneType] = true
            table.insert(types, zoneType)
        end
    end
    table.sort(types)
    MultiplayerZoneEditorMode_ZoneAPI.vanillaZoneTypes = types
    return types
end


function MultiplayerZoneEditorMode_ZoneAPI:onVanillaTicked(index, selected)
    local tickBox = self.vanillaOptions.tickBox
    local count = tickBox:getOptionCount()
    if index == 1 then
        for i=2, count do tickBox:setSelected(i, selected) end
    else
        local all = true
        for i=2, count do
            if not tickBox:isSelected(i) then all = false break end
        end
        tickBox:setSelected(1, all)
    end
    self:updateVanillaShown()
end


function MultiplayerZoneEditorMode_ZoneAPI:updateVanillaShown()
    self.vanillaShown = {}
    self.vanillaShownCount = 0
    local tickBox = self.vanillaOptions and self.vanillaOptions.tickBox
    if tickBox then
        for i=2, tickBox:getOptionCount() do
            if tickBox:isSelected(i) then
                self.vanillaShown[tickBox:getOptionData(i)] = true
                self.vanillaShownCount = self.vanillaShownCount + 1
            end
        end
    end
    self.vanillaCacheKey = nil
    local total = #MultiplayerZoneEditorMode_ZoneAPI.getVanillaZoneTypes()
    self.vanillaButton:setTitle(getText("IGUI_ZoneAPI_VanillaZones", tostring(self.vanillaShownCount), tostring(total)))
    self.vanillaButton:setWidthToTitle()
end


function MultiplayerZoneEditorMode_ZoneAPI:onToggleVanillaList(button)
    if self.vanillaOptions == nil then
        local ui = ZoneAPIVanillaZoneOptions:new(0, 0, 300, 300, self)
        self:addChild(ui)
        ui:setVisible(false)
        self.vanillaOptions = ui
    end
    if self.vanillaOptions:isVisible() then
        self.vanillaOptions:setVisible(false)
        return
    end
    self.vanillaOptions:setX(self.vanillaButton:getX())
    self.vanillaOptions:setY(self.vanillaButton:getBottom() + 2)
    self.vanillaOptions:setVisible(true)
end


function ZoneAPIVanillaZoneOptions:createChildren()
    local x = UI_BORDER_SPACING+1
    local y = self:titleBarHeight() + 6

    self.tickBox = ISTickBox:new(x, y, self.width, BUTTON_HGT, "", self.mode, self.mode.onVanillaTicked)
    self.tickBox:initialise()
    self.tickBox:addOption(getText("IGUI_ZoneAPI_Vanilla_All"), "*")
    for _,zoneType in ipairs(MultiplayerZoneEditorMode_ZoneAPI.getVanillaZoneTypes()) do self.tickBox:addOption(zoneType, zoneType) end
    self.tickBox:setWidthToFit()
    self:addChild(self.tickBox)

    self:setWidth(self.tickBox:getRight() + UI_BORDER_SPACING + 1)
    self:setHeight(self.tickBox:getBottom() + self:resizeWidgetHeight())
end


function ZoneAPIVanillaZoneOptions:onMouseDownOutside(x, y)
    if self:isMouseOver() or self.mode.vanillaButton:isMouseOver() then return end
    self:setVisible(false)
end


function ZoneAPIVanillaZoneOptions:new(x, y, width, height, mode)
    local o = ISCollapsableWindowJoypad.new(self, x, y, width, height)
    o.backgroundColor = {r=0, g=0, b=0, a=1.0}
    o.resizable = false
    o.mode = mode
    return o
end


function MultiplayerZoneEditorMode_ZoneAPI:getExportFileName() return "exportedZones_"..self.zoneType..".txt" end


function MultiplayerZoneEditorMode_ZoneAPI:onExport()
    local writer = getFileWriter(self:getExportFileName(), true, false)
    writer:write(zoneEditor.tableToString(self:getZones() or {}))
    writer:close()
    local cacheDir = Core.getMyDocumentFolder()..getFileSeparator().."Lua"
    if isDesktopOpenSupported() then showFolderInDesktop(cacheDir)
    else openUrl(cacheDir) end
end


function MultiplayerZoneEditorMode_ZoneAPI:onImport()
    local reader = getFileReader(self:getExportFileName(), false)
    if not reader then return end
    local lines = {}
    local line = reader:readLine()
    while line do
        table.insert(lines, line)
        line = reader:readLine()
    end
    reader:close()

    local tbl = zoneEditor.stringToTable(table.concat(lines, "\n"))
    if (not tbl) or (type(tbl)~="table") then
        print("ERROR: ZONE IMPORT FAILED.")
        return
    end
    self.selectedIndex = nil
    self:send("importZoneData", {zones=tbl})
end


function MultiplayerZoneEditorMode_ZoneAPI:closeModal()
    if not self.modalUI then return end
    self.modalUI:setVisible(false)
    self.modalUI:removeFromUIManager()
    self.modalUI = nil
end


function MultiplayerZoneEditorMode_ZoneAPI:display()
    MultiplayerZoneEditorMode.display(self)
    self.lastSelectedKey = nil
    if isClient() then sendClientCommand(getPlayer(), zoneEditor.MODULE, "loadZone", {zoneType=self.zoneType}) end
end


function MultiplayerZoneEditorMode_ZoneAPI:undisplay()
    if self.vanillaOptions then self.vanillaOptions:setVisible(false) end
    self:closeModal()
    self:cancelAction()
    self.clickCandidate = nil
    MultiplayerZoneEditorMode.undisplay(self)
end


function MultiplayerZoneEditorMode_ZoneAPI:new(editor, zoneType)
    local o = MultiplayerZoneEditorMode.new(self, editor)
    o.zoneType = zoneType
    o.resizer = WorldMapEditorResizer:new(editor)
    o.resizer.snapMode = "square"
    local module = zoneEditor.zoneTypes[zoneType]
    local color = module and module.color or {r=1, g=0.25, b=0.1}
    o.zoneR, o.zoneG, o.zoneB = color.r, color.g, color.b
    return o
end


zoneEditor.addListener(function(zoneType)
    local editor = ISMultiplayerZoneEditor_instance
    if not editor or not editor.mode then return end
    for _,mode in pairs(editor.mode) do
        if mode.zoneType == zoneType then mode.propertiesDirty = true end
    end
end)
