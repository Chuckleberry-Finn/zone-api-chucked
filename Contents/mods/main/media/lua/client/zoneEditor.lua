require "ISUI/ISPanel"

zoneEditor = ISPanel:derive("zoneEditor")
zoneEditor.instance = nil
zoneEditor.dataListObj = {}
zoneEditor.dataListName = {}


function zoneEditor.requestZone(zoneID)
    if not zoneEditor.loadedZones[zoneID] then sendClientCommand("zoneEditor", "loadZone", {zoneType=zoneID, disableRefresh=true}) end
    return zoneEditor.loadedZones[zoneID]
end


function zoneEditor.OnOpenPanel(obj, name)
    if not isAdmin() and not isCoopHost() and not getDebug() then return end

    if zoneEditor.instance==nil then
        local fontSizeAdjustment = 1 + (getCore():getOptionFontSize() * 0.15)
        zoneEditor.instance = zoneEditor:new(100, 100, 650*fontSizeAdjustment, 475*fontSizeAdjustment, "Inspect")
        sendClientCommand("zoneEditor", "loadAll", {zoneTypes=zoneEditor.zoneTypes})
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

function zoneEditor.addLabel(_self, _x, _y, _title, _font, _r, _g, _b, _a, _bLeft)
    local FONT_HGT = getTextManager():getFontHeight(_font)
    local label = ISLabel:new(_x, _y, FONT_HGT, _title, 1, 1, 1, 1.0, _font, _bLeft==nil and true or _bLeft)
    label:initialise()
    label:instantiate()
    _self:addChild(label)
    return label
end


function zoneEditor:createChildren()
    ISPanel.createChildren(self)

    self.header = zoneEditor.addLabel(self, 15, 8, "Zone Editor", UIFont.Large, true, 0.9, 0.9, 0.9)
    self.playerCoords = zoneEditor.addLabel(self, self.header.x+self.header.width+20, 8, "", UIFont.Small, true, 0.8,0.8,0.8)

    local comboWidth = self.width/3
    self.selectionComboBox = ISComboBox:new(self.width-comboWidth-8, 8, comboWidth, 22, self, self.onSelectZoneTypeChange)
    self.selectionComboBox.borderColor = { r = 1, g = 1, b = 1, a = 0.4 }
    self.selectionComboBox:initialise()
    self.selectionComboBox:instantiate()
    self:addChild(self.selectionComboBox)
    self:populateSelectionComboBoxComboList()

    local zoneListWidth = self.width-400
    local zoneListHeight = self.width-zoneListWidth-20

    local fontSizeAdjustment = 1 + (getCore():getOptionFontSize() * 0.15)

    self.zoneList = ISScrollingListBox:new(10, 40, zoneListWidth, zoneListHeight)
    self.zoneList:initialise()
    self.zoneList:instantiate()
    self.zoneList.itemheight = 22 * fontSizeAdjustment
    self.zoneList.joypadParent = self
    self.zoneList.font = UIFont.Small
    self.zoneList.doDrawItem = self.drawZoneList
    self.zoneList.drawBorder = true
    self.zoneList.onmousedown = zoneEditor.OnZoneListMouseDown
    self.zoneList.target = self
    self:addChild(self.zoneList)

    self.zoneEditPanel = ISScrollingListBox:new(self.zoneList.x+5, self.zoneList.y, zoneListWidth-10, 20)
    self.zoneEditPanel:initialise()
    self.zoneEditPanel:instantiate()
    self.zoneEditPanel.itemheight = 20 * fontSizeAdjustment
    self.zoneEditPanel.joypadParent = self
    self.zoneEditPanel.font = UIFont.Small
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
    self.editValueEntry.font = UIFont.Small
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

    local importExportW = 22
    local importX = self.selectionComboBox.x-importExportW-buttonPad

    self.importButton = ISButton:new(importX,self.selectionComboBox.y, importExportW,22, ">", self, zoneEditor.onClickImport)
    self.importButton.tooltip = getText("IGUI_IMPORT_ZONE")
    self.importButton:initialise()
    self.importButton:instantiate()
    self:addChild(self.importButton)

    self.exportButton = ISButton:new(importX-importExportW-buttonPad,self.selectionComboBox.y, importExportW,22, "<", self, zoneEditor.onClickExport)
    self.exportButton.tooltip = getText("IGUI_EXPORT_ZONE")
    self.exportButton:initialise()
    self.exportButton:instantiate()
    self:addChild(self.exportButton)

    self.scrollingZoom = 100
end


function zoneEditor.tableToString(object,nesting)
    nesting = nesting or 0
    local indent = "    "
    local text = ""..string.rep(indent, nesting)
    if type(object) == 'table' then
        local s = "{\n"
        for k,v in pairs(object) do
            s = s..string.rep(indent, nesting+1).."\[\""..k.."\"\] = "..zoneEditor.tableToString(v,nesting+1)..",\n"
        end
        text = s..string.rep(indent, nesting).."}"
    else
        if type(object) == "string" then text = "\""..tostring(object).."\""
        else text = tostring(object)
        end
    end
    return text
end

function zoneEditor.stringToTable(inputString)
    local tblString = inputString and loadstring(("return "..inputString))
    local tblTable = tblString and tblString()
    return tblTable
end


function zoneEditor:onClickImport()
    local zoneType = self:getSelectedZoneType()
    local reader = getFileReader("exportedZones_"..zoneType..".txt", false)
    if not reader then return end
    local lines = {}
    local line = reader:readLine()
    while line do
        table.insert(lines, line)
        line = reader:readLine()
    end
    reader:close()

    local totalStr = table.concat(lines, "\n")
    local tbl = zoneEditor.stringToTable(totalStr)
    if (not tbl) or (type(tbl)~="table") then
        print("ERROR: ZONE IMPORT FAILED.")
        return
    end
    sendClientCommand("zoneEditor", "importZoneData", {zoneType=zoneType,zones=tbl})
end


function zoneEditor:onClickExport()
    local cacheDir = Core.getMyDocumentFolder()..getFileSeparator().."Lua"..getFileSeparator().."exportedZones_"..self:getSelectedZoneType()..".txt"
    local zones = zoneEditor.loadedZones[self:getSelectedZoneType()]
    local exported = zoneEditor.tableToString(zones)
    local writer = getFileWriter("exportedZones_"..self:getSelectedZoneType()..".txt", true, false)
    writer:write(exported)
    writer:close()
    if isDesktopOpenSupported() then showFolderInDesktop(cacheDir)
    else openUrl(cacheDir) end
end


function zoneEditor:onClickClose() self:close() end


zoneEditor.ignore = {}
zoneEditor.zoneTypes = {}
zoneEditor.currentZone = nil
zoneEditor.loadedZones = {}

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
end


function zoneEditor:onSelectZoneTypeChange() self:populateZoneList() end


function zoneEditor:onClickAddZone()
    local selected = self:getSelectedZoneType()
    if not selected then return end
    local zoneType = zoneEditor.zoneTypes[selected]
    if not zoneType then return end
    local newZone = copyTable(zoneType.Zone)
    if not newZone then return end
    sendClientCommand("zoneEditor", "addZone", {zoneType=selected, newZone=newZone})
    self.refresh = 2
end


function zoneEditor:onClickRemoveZone()
    if not zoneEditor.currentZone then return end
    local selected = self:getSelectedZoneType()
    if not selected then return end
    sendClientCommand("zoneEditor", "removeZone", {zoneType=selected,selected=self.zoneList.selected})
    self.refresh = 2
end


function zoneEditor:OnZoneListMouseDown(item)
    local zone = self.zoneList.items and self.zoneList.items[self.zoneList.selected] and self.zoneList.items[self.zoneList.selected].item
    zoneEditor.instance:populateZoneEditPanel(zone)
end


function zoneEditor:OnZoneEditPanelMouseDown(item, test, test2)
    zoneEditor.instance.zoneEditPanel.clickSelected = item
    local backup = zoneEditor.instance.zoneList.selected
    zoneEditor.instance:populateZoneList(backup)
end


function zoneEditor:populateZoneList(selectedBackup)
    self.zoneList:clear()
    self.refresh = 0
    self.removeZoneButton:setVisible(false)
    self.zoneEditPanel:setVisible(false)

    local selected = self:getSelectedZoneType()
    if not selected then return end

    sendClientCommand("zoneEditor", "loadZone", {zoneType=selected, disableRefresh=true})

    zoneEditor.currentZone = zoneEditor.loadedZones[selected]

    if zoneEditor.currentZone then
        if selectedBackup then self.zoneList.selected = selectedBackup end
        for i, zone in pairs(zoneEditor.currentZone) do
            local label = zone and zone.name or zone.coordinates
                    and zone.coordinates.x1 and zone.coordinates.x2 and zone.coordinates.y1 and zone.coordinates.y2
                    and "x1:"..zone.coordinates.x1..", y1:"..zone.coordinates.y1..", x2:"..zone.coordinates.x2..", y2:"..zone.coordinates.y2
                    or "damaged zone"
            self.zoneList:addItem(label, zone)
        end
        self:populateZoneEditPanel()
    end
end


function zoneEditor:populateZoneEditPanel(oldZone)

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

    local newValue = self:getText()
    if newValue == "" or newValue == nil then
        zoneEditor.instance.zoneEditPanel.clickSelected = nil
        self:setVisible(false)
        return
    end

    local zoneSelected = zoneEditor.instance.zoneList.selected
    local zone = zoneEditor.instance.zoneList.items[zoneSelected] and zoneEditor.instance.zoneList.items[zoneSelected].item
    local parentParam
    local param = zone and zone[zoneEditor.instance.zoneEditPanel.clickSelected]
    if not zone then return end

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

    local oldType = (param=="true" or param=="false") and "%BOOL%" or type(param)
    local newKey = zoneEditor.instance.zoneEditPanel.clickSelected

    if oldType == "number" then newValue = tonumber(newValue) end
    if oldType == "%BOOL%" and newValue~="true" and newValue~="false" then newValue = nil end
    if oldType ~= "%BOOL%" and (newValue=="true" or newValue=="false") then newValue = nil end

    if newValue == "" or newValue == nil then
        zoneEditor.instance.zoneEditPanel.clickSelected = nil
        self:setVisible(false)
        return
    end

    local zoneType = zoneEditor.instance.selectionComboBox:getOptionData(zoneEditor.instance.selectionComboBox.selected)
    sendClientCommand("zoneEditor", "editZoneData", {zoneType=zoneType,selected=zoneSelected,parentParam=parentParam,newKey=newKey,newValue=newValue})

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


zoneEditor.highLights = {}
zoneEditor.highLightedZone = {x1=-1,y1=-1,x2=-1,y2=-1}
---CREDIT: Bambino (_bambino)
function zoneEditor.processZoneHighlight(zone)
    if not zone or not zone.coordinates or zone.coordinates.x1 < 0 or zone.coordinates.x2 < 0 or zone.coordinates.y1 < 0 or zone.coordinates.y2 < 0 then
        zoneEditor.clearZoneHighlight()
        return
    end

    if zone.coordinates.x1 == zoneEditor.highLightedZone.x1 and zone.coordinates.x2 == zoneEditor.highLightedZone.x2
            and zone.coordinates.y1 == zoneEditor.highLightedZone.y1 and zone.coordinates.y2 == zoneEditor.highLightedZone.y2 then
        return
    end
    zoneEditor.highLightedZone = {x1=zone.coordinates.x1,y1=zone.coordinates.y1,x2=zone.coordinates.x2,y2=zone.coordinates.y2}

    local zoneX1 = math.min(zone.coordinates.x1, zone.coordinates.x2)
    local zoneX2 = math.max(zone.coordinates.x1, zone.coordinates.x2)
    local zoneY1 = math.min(zone.coordinates.y1, zone.coordinates.y2)
    local zoneY2 = math.max(zone.coordinates.y1, zone.coordinates.y2)

    local definitiveTiles = {}

    for xVal = zoneX1, zoneX2 do

        local yVal1 = zoneY1
        local square1 = getSquare(xVal,yVal1,0)
        if square1 then
            zoneEditor.highlightSquare(square1, xVal, yVal1)
            definitiveTiles[xVal] = definitiveTiles[xVal] or {}
            definitiveTiles[xVal][yVal1] = true
        end

        local yVal2 = zoneY2
        local square2 = getSquare(xVal,yVal2,0)
        if square2 then
            zoneEditor.highlightSquare(square2, xVal, yVal2)
            definitiveTiles[xVal] = definitiveTiles[xVal] or {}
            definitiveTiles[xVal][yVal2] = true
        end

    end

    for yVal = zoneY1, zoneY2 do

        local xVal1 = zoneX1
        local square1 = getSquare(xVal1, yVal, 0)
        if square1 then
            zoneEditor.highlightSquare(square1, xVal1, yVal)
            definitiveTiles[xVal1] = definitiveTiles[xVal1] or {}
            definitiveTiles[xVal1][yVal] = true
        end

        local xVal2 = zoneX2
        local square2 = getSquare(xVal2, yVal, 0)
        if square2 then
            zoneEditor.highlightSquare(square2, xVal2, yVal)
            definitiveTiles[xVal2] = definitiveTiles[xVal2] or {}
            definitiveTiles[xVal2][yVal] = true
        end

    end

    --[[
    for x = zoneX1, zoneX2 do
        for y = zoneY1, zoneY2 do
            local sq = getSquare(x, y, 0)
            if sq then
                zoneEditor.highlightSquare(sq, x, y)
                definitiveTiles[x] = definitiveTiles[x] or {}
                definitiveTiles[x][y] = true
            end
        end
    end
    --]]

    zoneEditor.clearZoneHighlight(definitiveTiles)
end


function zoneEditor.clearZoneHighlight(definitiveTiles)
    if not zoneEditor.highLights then return end
    for x,ys in pairs(zoneEditor.highLights) do
        for y, marker in pairs(ys) do
            if not definitiveTiles or not definitiveTiles[x] or not definitiveTiles[x][y] then
                if zoneEditor.highLights[x][y] then
                    marker:remove()
                    zoneEditor.highLights[x][y] = nil
                end
            end
        end
    end
    if not definitiveTiles then zoneEditor.highLightedZone = {} end
end


function zoneEditor.highlightSquare(sq, x, y)
    if not zoneEditor.highLights[x] then zoneEditor.highLights[x] = {} end
    if not zoneEditor.highLights[x][y] then
        zoneEditor.highLights[x][y] = getWorldMarkers():addGridSquareMarker("square_center", nil, sq, 1, 0, 0, false, 1.0)
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
            self:populateZoneList(self.zoneList.selected)
        end
    end

    local player = getPlayer()

    if zoneEditor.currentZone then
        for i, zone in pairs(zoneEditor.currentZone) do
            if zone and zone.coordinates and zone.coordinates.x1 then

                local zoneX1 = math.min(zone.coordinates.x1, zone.coordinates.x2)
                local zoneX2 = math.max(zone.coordinates.x1, zone.coordinates.x2)
                local zoneY1 = math.min(zone.coordinates.y1, zone.coordinates.y2)
                local zoneY2 = math.max(zone.coordinates.y1, zone.coordinates.y2)

                local zoneW, zoneH = scale*((zoneX2-zoneX1)/mapSizeX), scale*((zoneY2-zoneY1)/mapSizeY)
                local zoneX, zoneY = zoneMapX+scale*(zoneX1/mapSizeX), zoneMapY+scale*(zoneY1/mapSizeY)

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
    local zone = self.zoneList.items and self.zoneList.items[self.zoneList.selected] and self.zoneList.items[self.zoneList.selected].item
    zoneEditor.processZoneHighlight(zone)

    ISPanel.render(self)
end


function zoneEditor:update() ISPanel.update(self) end


function zoneEditor:close()
    self:setVisible(false)
    zoneEditor.clearZoneHighlight()
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
    local fontHeight = getTextManager():getFontHeight(UIFont.Small)
    local btnWid = 150
    local btnHgt = math.max(25, fontHeight + 3 * 2)
    local btnGapY = 5

    local lastButton = self.children[self.IDMax-1]
    lastButton = lastButton.internal == "CANCEL" and self.children[self.IDMax-2] or lastButton
    
    self.showZoneEditor = ISButton:new(lastButton.x, lastButton.y+btnHgt+btnGapY, btnWid, btnHgt, "Zone Editor", self, zoneEditor.OnOpenPanel)
    self.showZoneEditor.internal = ""
    self.showZoneEditor:initialise()
    self.showZoneEditor:instantiate()
    self.showZoneEditor.borderColor = self.buttonBorderColor
    self:addChild(self.showZoneEditor)

end