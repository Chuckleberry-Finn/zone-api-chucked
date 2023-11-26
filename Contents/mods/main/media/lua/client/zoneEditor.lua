require "ISUI/ISPanel"

zoneEditor = ISPanel:derive("zoneEditor")
zoneEditor.instance = nil
zoneEditor.dataListObj = {}
zoneEditor.dataListName = {}


function zoneEditor.requestZone(zoneID)
    if isClient() then ModData.request(zoneID.."_zones") end
    return ModData.get(zoneID.."_zones")
end


function zoneEditor.OnOpenPanel(obj, name)
    if not isAdmin() and not isCoopHost() and not getDebug() then return end

    if zoneEditor.instance==nil then
        zoneEditor.instance = zoneEditor:new(100, 100, 650, 475, "Inspect")
        zoneEditor.instance:initialise()
        zoneEditor.instance:instantiate()
    end

    zoneEditor.instance:addToUIManager()
    zoneEditor.instance:setVisible(true)
    zoneEditor.instance:populateZoneList()

    return zoneEditor.instance
end


function zoneEditor:initialise()
    ISPanel.initialise(self)
    self.firstTableData = false
end


function zoneEditor:supplantMouseWheel(del) self.parent:onMouseWheel(del) end


function zoneEditor:getSelectedZoneType()
    if not self.selectionComboBox.selected then return end
    local selected = self.selectionComboBox:getOptionData(self.selectionComboBox.selected)
    return selected
end


function zoneEditor:populateSelectionComboBoxComboList()
    --[fileName]=newZoneModule
    self.selectionComboBox:clear()
    for fileName,newZoneModule in pairs(self.zoneTypes) do
        self.selectionComboBox:addOptionWithData(fileName, fileName)
    end
    if (not self.selectionComboBox.selected) or (self.selectionComboBox.selected > #self.selectionComboBox.options) then self.selectionComboBox.selected = 1 end
end


function zoneEditor:createChildren()
    ISPanel.createChildren(self)

    self.junk, self.header = ISDebugUtils.addLabel(self, {}, 15, 8, "Zone Editor", UIFont.Large, true)
    self.header:setColor(0.9,0.9,0.9)

    self.junk, self.playerCoords = ISDebugUtils.addLabel(self, {}, self.header.x+self.header.width+20, 8, "", UIFont.Small, true)
    self.header:setColor(0.8,0.8,0.8)

    local comboWidth = self.width/3
    self.selectionComboBox = ISComboBox:new(self.width-comboWidth-8, 8, comboWidth, 22, self, self.onSelectZoneTypeChange)
    self.selectionComboBox.borderColor = { r = 1, g = 1, b = 1, a = 0.4 }
    self.selectionComboBox:initialise()
    self.selectionComboBox:instantiate()
    self:addChild(self.selectionComboBox)
    self:populateSelectionComboBoxComboList()

    local zoneListWidth = self.width-400
    local zoneListHeight = self.width-zoneListWidth-20

    self.zoneList = ISScrollingListBox:new(10, 40, zoneListWidth, zoneListHeight)
    self.zoneList:initialise()
    self.zoneList:instantiate()
    self.zoneList.itemheight = 22
    self.zoneList.joypadParent = self
    self.zoneList.font = UIFont.NewSmall
    self.zoneList.doDrawItem = self.drawZoneList
    self.zoneList.drawBorder = true
    self.zoneList.onmousedown = zoneEditor.OnZoneListMouseDown
    self.zoneList.target = self
    self:addChild(self.zoneList)

    self.zoneEditPanel = ISScrollingListBox:new(self.zoneList.x+5, self.zoneList.y, zoneListWidth-10, 20)
    self.zoneEditPanel:initialise()
    self.zoneEditPanel:instantiate()
    self.zoneEditPanel.itemheight = 20
    self.zoneEditPanel.joypadParent = self
    self.zoneEditPanel.font = UIFont.NewSmall
    self.zoneEditPanel.doDrawItem = self.drawZoneEditPanel
    self.zoneEditPanel.drawBorder = false
    self.zoneEditPanel.onmousedown = zoneEditor.OnZoneEditPanelMouseDown
    self.zoneEditPanel.onMouseWheel = zoneEditor.supplantMouseWheel
    self.zoneEditPanel.target = self
    self:addChild(self.zoneEditPanel)
    self.zoneEditPanel:setVisible(false)

    self.editValueEntry = ISTextEntryBox:new("", self.zoneEditPanel.x, 0, self.zoneEditPanel.width, self.zoneEditPanel.itemheight)
    self.editValueEntry:initialise()
    self.editValueEntry:instantiate()
    self.editValueEntry.font = UIFont.NewSmall
    self.editValueEntry.borderColor = { r = 0.5, g = 0.5, b = 0.5, a = 0.5 }
    self.editValueEntry.onCommandEntered = self.onEnterValueEntry
    self:addChild(self.editValueEntry)
    self.editValueEntry:setVisible(false)

    local w = self.zoneList.width
    local buttonH, buttonW, buttonPad = 20, 100, 10

    self:setHeight(self.zoneList.y+self.zoneList.height+buttonH+(buttonPad*2))

    local y, button = ISDebugUtils.addButton(self,"close",self.width-buttonW-buttonPad,self.height-buttonPad-buttonH, buttonW,buttonH, "Close", zoneEditor.onClickClose)
    self.closeButton = button

    y, button = ISDebugUtils.addButton(self,"addZone", buttonPad,self.height-buttonPad-buttonH, buttonW,buttonH, "Add Zone", zoneEditor.onClickAddZone)
    self.addZoneButton = button

    y, button = ISDebugUtils.addButton(self,"X", self.zoneList.x+self.zoneList.width-23,3, 18,18, "X", zoneEditor.onClickRemoveZone)
    self.removeZoneButton = button
    self.removeZoneButton:setVisible(false)

    self.scrollingZoom = 100
end


function zoneEditor:onClickClose() self:close() end


zoneEditor.ignore = {}
zoneEditor.zoneTypes = {}

function zoneEditor.addZoneType(fileName)
    local newZoneModule = require(fileName)

    if not newZoneModule then print("ERROR: ZoneType derived from: \"..fileName..\".lua\" is returning nil.") return end
    if not newZoneModule.Zone then print("ERROR: ZoneType derived from: \"..fileName..\".lua\" has no 'Zone'.") return end
    if not newZoneModule.Zone.coordinates then print("ERROR: ZoneType derived from: \"..fileName..\".lua\" has no 'coordinates'.") return end

    if newZoneModule.ignore then
        for k,v in pairs(newZoneModule.ignore) do
            zoneEditor.ignore[k] = v
        end
    end
    zoneEditor.zoneTypes[fileName]=newZoneModule

    sendClientCommand("zoneEditor", "addZoneTypeToServer", {zoneType=fileName})
end


function zoneEditor:onSelectZoneTypeChange()
    self:populateZoneList()
end


function zoneEditor:onClickAddZone()
    local selected = self:getSelectedZoneType()
    if not selected then return end
    local zoneType = zoneEditor.zoneTypes[selected]
    if not zoneType then return end
    local newZone = copyTable(zoneType.Zone)
    if not newZone then return end
    if not self.zones then return end
    table.insert(self.zones, newZone)
    ModData.transmit(selected.."_zones")
    self.refresh = 2
end


function zoneEditor:onClickRemoveZone()
    if not self.zones then return end
    local selected = self:getSelectedZoneType()
    if not selected then return end
    for i, zone in pairs(self.zones) do
        if self.zoneList.items[self.zoneList.selected].item == zone then
            self.zones[i] = nil
            ModData.transmit(selected.."_zones")
        end
    end
    self:populateZoneList()
end


function zoneEditor:OnZoneListMouseDown(item)
    zoneEditor.instance:populateZoneEditPanel()
end

function zoneEditor:OnZoneEditPanelMouseDown(item, test, test2)
    zoneEditor.instance.zoneEditPanel.clickSelected = item
    local backup = zoneEditor.instance.zoneList.selected
    zoneEditor.instance:populateZoneList(backup)
end


function zoneEditor.receiveGlobalModData(name, data)
    if name and data and type(data) == "table" then
        if zoneEditor.zoneTypes[name] and data and type(data) == "table" then
            local modDataID = name.."_zones"
            if ModData.exists(modDataID) then ModData.remove(modDataID) end
            ModData.add(modDataID,data)
        end
    end
end
Events.OnReceiveGlobalModData.Add(zoneEditor.receiveGlobalModData)


function zoneEditor:populateZoneList(selectedBackup)
    self.zoneList:clear()
    self.refresh = 0
    self.removeZoneButton:setVisible(false)
    self.zoneEditPanel:setVisible(false)

    local selected = self:getSelectedZoneType()
    if not selected then return end

    if isClient() then ModData.request(selected.."_zones") end

    self.zones = ModData.getOrCreate(selected.."_zones")

    if self.zones then
        if selectedBackup then self.zoneList.selected = selectedBackup end
        for i, zone in pairs(self.zones) do

            local label = "damaged zone"
            if zone and zone.coordinates and zone.coordinates.x1 then
                label = "x1:"..zone.coordinates.x1..", y1:"..zone.coordinates.y1..", x2:"..zone.coordinates.x2..", y2:"..zone.coordinates.y2
            end
            self.zoneList:addItem(label, zone)
        end
        self:populateZoneEditPanel()
    end
end


function zoneEditor:populateZoneEditPanel()

    local zone = self.zoneList.items and self.zoneList.items[self.zoneList.selected] and self.zoneList.items[self.zoneList.selected].item
    if zone then

        local backup = self.zoneEditPanel.selected
        self.zoneEditPanel:clear()

        self.zoneEditPanel.additionalSublistRows = 0

        local selected = self:getSelectedZoneType()
        local tooltips = self.zoneTypes[selected] and self.zoneTypes[selected].tooltips

        for param, value in pairs(zone) do
            if not zoneEditor.ignore[param] then

                self.zoneEditPanel.openedSublist = self.zoneEditPanel.openedSublist or {}

                local clickedCurrentParam = self.zoneEditPanel.clickSelected == param
                local valueIsTable = type(value) == "table"

                local labelValue = (not valueIsTable) and " = "..value or ""

                if valueIsTable then
                    if clickedCurrentParam then
                        self.zoneEditPanel.clickSelected = nil
                        if not self.zoneEditPanel.openedSublist[param] then self.zoneEditPanel.openedSublist[param] = true
                        else self.zoneEditPanel.openedSublist[param] = nil end
                    end

                    if not self.zoneEditPanel.openedSublist[param] then labelValue = "   []"
                    else labelValue = "   [  ]" end
                end

                local option = self.zoneEditPanel:addItem(param..labelValue, param)
                option.isTable = valueIsTable

                option.tooltip = tooltips and tooltips[param] or nil

                if self.zoneEditPanel.openedSublist[param] then
                    if valueIsTable then
                        for key,val in pairs(value) do
                            self.zoneEditPanel.additionalSublistRows = self.zoneEditPanel.additionalSublistRows+1
                            local subOption = self.zoneEditPanel:addItem("     "..key.."="..val, key)
                            subOption.childOf = param
                        end
                    end
                end
            end
        end

        self.zoneEditPanel.selected = backup
    end
end


function zoneEditor:drawZoneEditPanel(y, item, alt)
    local a = 0.9
    local itemHeight = self.itemheight

    if zoneEditor.instance.zoneEditPanel.clickSelected and zoneEditor.instance.zoneEditPanel.clickSelected == item.item and (not item.isTable) then
        zoneEditor.instance.editValueEntry:setY(y+zoneEditor.instance.zoneEditPanel.y)

        zoneEditor.instance.editValueEntry:setVisible(false)
        local zone = zoneEditor.instance.zoneList.items[zoneEditor.instance.zoneList.selected].item
        local param = item.childOf and zone[item.childOf] and zone[item.childOf][item.item] or zone[item.item]
        if param then
            if not zoneEditor.instance.editValueEntry:isFocused() then
                zoneEditor.instance.editValueEntry:focus()
                zoneEditor.instance.editValueEntry:setText(tostring(param))
            end
            zoneEditor.instance.editValueEntry:setVisible(true)
        end
    end

    self:drawRectBorder(0, (y), self:getWidth(), itemHeight - 1, a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
    self:drawText( item.text, 10, y + 2, 1, 1, 1, a, self.font)
    return y + itemHeight
end


function zoneEditor:onEnterValueEntry()

    self:unfocus()

    local zone = zoneEditor.instance.zoneList.items[zoneEditor.instance.zoneList.selected].item
    local parentParam
    local param = zone[zoneEditor.instance.zoneEditPanel.clickSelected]

    if not param then
        for zoneParam,value in pairs(zone) do
            if type(value) == "table" then
                local foundParam = zone[zoneParam][zoneEditor.instance.zoneEditPanel.clickSelected]
                if foundParam then
                    parentParam = zoneParam
                    param = foundParam
                end
            end
        end
    end

    local oldType = type(param)
    local newKey = zoneEditor.instance.zoneEditPanel.clickSelected
    local newValue = self:getText()

    if oldType == "number" then newValue = tonumber(newValue) end

    if newValue and newValue~="" then
        if zoneEditor.instance.zoneEditPanel.clickSelected ~= newKey then
            if parentParam then
                zone[parentParam][zoneEditor.instance.zoneEditPanel.clickSelected] = nil
            else
                zone[zoneEditor.instance.zoneEditPanel.clickSelected] = nil
            end
        end

        if parentParam then
            zone[parentParam][newKey] = newValue
        else
            zone[newKey] = newValue
        end
    end

    ModData.transmit(zoneEditor.instance.selectionComboBox:getOptionData(zoneEditor.instance.selectionComboBox.selected).."_zones")

    zoneEditor.instance.zoneEditPanel.clickSelected = nil
    self:setVisible(false)
    zoneEditor.instance:populateZoneEditPanel()
end


function zoneEditor:drawZoneList(y, item, alt)
    local a = 0.9
    local itemHeight = self.itemheight
    local zoneEditPanelH = 0

    if self.selected == item.index then
        itemHeight = ((self.fontHgt + (self.itemPadY or 0) * 2))

        zoneEditPanelH = self.parent.zoneEditPanel.itemheight*self.parent.zoneEditPanel.count
        itemHeight = itemHeight + (zoneEditPanelH)

        self:drawRect(0, (y), self:getWidth(), (itemHeight-1), 0.3, 0.7, 0.35, 0.15)
        self.parent.zoneEditPanel:setY(self.parent.zoneList:getYScroll()+(self.itemheight*2)+self.parent.zoneList.y+y-13)

        if self.parent.zoneList:isVScrollBarVisible() then
            local scrollWidth = self.parent.zoneList.vscroll.width
            self.parent.removeZoneButton:setX(self.parent.zoneList.x+self.parent.zoneList.width-18-scrollWidth)
            self.parent.zoneEditPanel:setWidth(self.parent.zoneList.width-5-scrollWidth)
        else
            self.parent.removeZoneButton:setX(self.parent.zoneList.x+self.parent.zoneList.width-23)
            self.parent.zoneEditPanel:setWidth(self.parent.zoneList.width-10)
        end

        self.parent.zoneEditPanel:setHeight(zoneEditPanelH)
        self.parent.zoneEditPanel:setVisible(true)

        self.parent.removeZoneButton:setY(self.parent.zoneList:getYScroll()+self.parent.zoneList.y+y+3)
        self.parent.removeZoneButton:setVisible(true)
    end

    self:drawRectBorder(0, (y), self:getWidth(), (itemHeight-1), a, self.borderColor.r, self.borderColor.g, self.borderColor.b)

    self:drawText( item.text, 10, y + 2, 1, 1, 1, a, self.font)
    return y + itemHeight
end


function zoneEditor:onMouseWheel(del)
    local scale = self.width-self.zoneList.width-20
    local zoneMapX, zoneMapY = self.zoneList.x+self.zoneList.width+5, self.zoneList.y
    local mouseX, mouseY = self:getMouseX(), self:getMouseY()

    self.scrollingZoom = self.scrollingZoom-(del)
    self.scrollingZoom = math.max(1,math.min(100,self.scrollingZoom))

    if mouseX > zoneMapX and mouseX < zoneMapX+scale and mouseY > zoneMapY and mouseY < zoneMapY+scale then return true end
    return false
end


---@param square IsoGridSquare
function zoneEditor.highlightSquare(square, player)
    ---@type IsoObject
    local sqFloor = square and square:getFloor()
    if not sqFloor then return end
    local tooFar = (math.abs(player:getX()-sqFloor:getX())>55) or (math.abs(player:getX()-sqFloor:getX())>55)
    if tooFar then return end
    sqFloor:setHighlighted(true)
    sqFloor:setHighlightColor(1,0,0,1)
end


---@param playerObj IsoGameCharacter|IsoPlayer|IsoObject|IsoMovingObject
function zoneEditor.highlightZone(x1,y1,x2,y2,playerObj)

    for xVal = x1, x2 do
        local yVal1 = y1
        local yVal2 = y2
        local square1 = getSquare(xVal,yVal1,0)
        zoneEditor.highlightSquare(square1, playerObj)
        local square2 = getSquare(xVal,yVal2,0)
        zoneEditor.highlightSquare(square2, playerObj)

    end

    for yVal = y1, y2 do
        local xVal1 = x1
        local xVal2 = x2
        local square1 = getSquare(xVal1,yVal,0)
        zoneEditor.highlightSquare(square1, playerObj)
        local square2 = getSquare(xVal2,yVal,0)
        zoneEditor.highlightSquare(square2, playerObj)
    end
end


function zoneEditor:prerender()
    ISPanel.prerender(self)

    local scale = self.width-self.zoneList.width-20
    local zoneMapX, zoneMapY = self.zoneList.x+self.zoneList.width+5, self.zoneList.y

    local metaGrid = getWorld():getMetaGrid()
    local cellsX, cellsY = metaGrid:getWidth(), metaGrid:getHeight()
    local mapSizeX, mapSizeY = cellsX*300, cellsY*300

    for i=0, cellsY do
        local yPos = (zoneMapY+((scale/cellsY)*i))
        --if yPos < zoneMapY+scale then
        self:drawTextureScaledStatic(nil, zoneMapX, yPos, scale, 1, 0.1, 1, 0, 1)
    end

    for i=0, cellsX do
        local xPos = (zoneMapX+((scale/cellsX)*i))
        --if xPos < zoneMapX+scale then
        self:drawTextureScaledStatic(nil, xPos, zoneMapY, 1, scale, 0.1, 1, 1, 0)
    end

    if self.refresh and self.refresh > 0 then
        self.refresh = self.refresh-1
        if self.refresh <= 0 then
            self:populateZoneList()
        end
    end

    local player = getPlayer()

    if self.zones then
        for i, zone in pairs(self.zones) do
            if zone and zone.coordinates and zone.coordinates.x1 then
                local zoneW, zoneH = scale*(math.abs(zone.coordinates.x2-zone.coordinates.x1)/mapSizeX), scale*(math.abs(zone.coordinates.y2-zone.coordinates.y1)/mapSizeY)
                local zoneX, zoneY = zoneMapX+scale*(zone.coordinates.x1/mapSizeX), zoneMapY+scale*(zone.coordinates.y1/mapSizeY)

                self:drawRect(zoneX, zoneY, math.max(1,zoneW), math.max(1,zoneH), 0.5, 1, 0, 0)

                if self.zoneList.items and self.zoneList.items[self.zoneList.selected] and self.zoneList.items[self.zoneList.selected].item == zone then
                    self:drawRectBorder(zoneX, zoneY, math.max(1,zoneW), math.max(1,zoneH), 0.5, 1, 1, 1)
                end
            end
        end
    end

    local playerX, playerY = zoneMapX+scale*(player:getX()/mapSizeX), zoneMapY+scale*(player:getY()/mapSizeY)
    self:drawRect(playerX, playerY, math.max(1,1), math.max(1,1), 0.7, 0, 1, 0)

    self.playerCoords:setName("x:"..tostring(player:getX())..", y:"..tostring(player:getY()))

    self:drawRectBorder(zoneMapX, zoneMapY, scale, scale, 0.7, 0.7, 0.7, 0.7)
end


function zoneEditor:render()
    ISPanel.render(self)
    
    if self.zones then
        local player = getPlayer()
        for i, zone in pairs(self.zones) do
            if zone and zone.coordinates and zone.coordinates.x1 then
                zoneEditor.highlightZone(zone.coordinates.x1,zone.coordinates.y1,zone.coordinates.x2,zone.coordinates.y2,player)
            end
        end
    end
end

function zoneEditor:update()
    ISPanel.update(self)
end


function zoneEditor:close()
    self:setVisible(false)
    self:removeFromUIManager()
end


function zoneEditor:new(x, y, width, height, title)
    local o = {}
    o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.variableColor={r=0.9, g=0.55, b=0.1, a=1}
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
    o.backgroundColor = {r=0, g=0, b=0, a=0.8}
    o.buttonBorderColor = {r=0.7, g=0.7, b=0.7, a=0.5}
    o.zOffsetSmallFont = 25
    o.moveWithMouse = true
    o.panelTitle = title
    ISDebugMenu.RegisterClass(self)
    return o
end


require "DebugUIs/DebugMenu/ISDebugMenu"
local ISDebugMenu_setupButtons = ISDebugMenu.setupButtons
function ISDebugMenu:setupButtons()
    self:addButtonInfo("Zone Editor", function() zoneEditor.OnOpenPanel() end, "MAIN")
    ISDebugMenu_setupButtons(self)
end

require "ISUI/AdminPanel/ISAdminPanelUI"
local ISAdminPanelUI_create = ISAdminPanelUI.create
function ISAdminPanelUI:create()
    ISAdminPanelUI_create(self)
    local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
    local btnWid = 150
    local btnHgt = math.max(25, FONT_HGT_SMALL + 3 * 2)
    local btnGapY = 5

    self.showZoneEditor = ISButton:new(self.showStatisticsBtn.x, self.showStatisticsBtn.y+btnHgt+btnGapY, btnWid, btnHgt, "Zone Editor", self, zoneEditor.OnOpenPanel)
    self.showZoneEditor.internal = ""
    self.showZoneEditor:initialise()
    self.showZoneEditor:instantiate()
    self.showZoneEditor.borderColor = self.buttonBorderColor
    self:addChild(self.showZoneEditor)

end