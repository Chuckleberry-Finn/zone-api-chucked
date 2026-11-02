local zoneEditorServer = require "zoneEditorServer"
Events.OnClientCommand.Add(zoneEditorServer.onClientCommand)
Events.OnInitGlobalModData.Add(zoneEditorServer.onInitGlobalModData)
