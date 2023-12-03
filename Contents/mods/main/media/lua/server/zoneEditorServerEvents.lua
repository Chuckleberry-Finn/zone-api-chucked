local zoneEditorServer = require "zoneEditorServer"
if isServer() then
    Events.OnReceiveGlobalModData.Add(zoneEditorServer.receiveGlobalModData)
    Events.OnClientCommand.Add(zoneEditorServer.onClientCommand)--/client/ to server
end