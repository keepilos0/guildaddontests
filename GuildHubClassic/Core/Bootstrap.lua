local addonName, ns = ...

ns.name = addonName
ns.version = "0.2.0-alpha.1"
ns.protocolVersion = 1
ns.schemaVersion = 1
ns.addonPrefix = "GHC1"
ns.modules = {}
ns.ui = {}
ns.constants = {
    requestMinLevel = 6,
    maxActiveRequests = 5,
    maxActiveGroups = 3,
    archiveRetentionSeconds = 90 * 24 * 60 * 60,
    groupArchiveDelaySeconds = 2 * 60 * 60,
    requestDurations = { 1, 6, 12, 24, 72, 168 },
}

local AceAddon = LibStub and LibStub("AceAddon-3.0", true)
if AceAddon then
    ns.Addon = AceAddon:NewAddon("GuildHubClassicCore", "AceEvent-3.0", "AceComm-3.0")
else
    ns.Addon = {}
end

function ns:RegisterModule(name, module)
    self.modules[name] = module
    return module
end

function ns:Print(message)
    local text = tostring(message or "")
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cffe6b84cGuild Hub Classic:|r " .. text)
    else
        print("Guild Hub Classic: " .. text)
    end
end
