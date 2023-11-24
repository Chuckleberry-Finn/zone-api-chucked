local zoneEditorServer = require("zoneEditorServer")
Events.OnReceiveGlobalModData.Add(zoneEditorServer.receiveGlobalModData)
Events.OnClientCommand.Add(zoneEditorServer.onClientCommand)--/client/ to server