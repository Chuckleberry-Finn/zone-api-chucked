---This is to prevent non debug people from getting the example zone loaded in
if not getDebug() then return end

---Create a module for loading with `require`
local exampleZoneType = {}

--This is just a simple lua table / module - you can apply functions or other behaviors as needed.
--See the mod: Mining Chucked, for an example of this.

---template zone:
--This sub-table will populate the zone list for editing
--Anything that is a table within this table will display a drop down (shown as [])
--Any values in the sub-table can be edited as well.
exampleZoneType.Zone = {
    name = "newZone",
    --Required values: coordinates, which is a table of x1, y1, x2, y2
    coordinates={x1=-1, y1=-1, x2=-1, y2=-1},
    --Other values can be added here if you wish to utilize this file as a module outside of zoneEditor.
    --Adding the value's key into .ignore will ignore it from display - this is useful for background data/values.
    ignoreExample = {"a", "b"},
}

exampleZoneType.tooltips = nil --{coordinates="These are coordinates."}

--Optional: label in the zone editor, the Capability required to edit, and the colour drawn on the map.
exampleZoneType.displayName = "Example Zones"
exampleZoneType.capability = "CanSetupNonPVPZone"
exampleZoneType.color = {r=0.2, g=0.6, b=1.0}

--All keys have to equal true (or another non-false/nil value - if you want to utilize the value for something outside of the ZoneEditor)
exampleZoneType.ignore = {["ignoreExample"]=true}

--Finally, return the module as the table
return exampleZoneType