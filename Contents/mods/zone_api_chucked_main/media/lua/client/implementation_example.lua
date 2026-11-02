---EXAMPLE:
--This is to prevent non debug people from getting the example zone loaded in
if not getDebug() then return end

require "zoneEditor"
zoneEditor.addZoneType("EXAMPLE_ZONE_TYPE")