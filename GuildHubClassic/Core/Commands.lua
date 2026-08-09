local _, ns = ...

local Commands = {}
ns.Commands = Commands

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

function Commands:Register()
    SLASH_GUILDHUBCLASSIC1 = "/gh"
    SLASH_GUILDHUBCLASSIC2 = "/guildhub"
    SlashCmdList.GUILDHUBCLASSIC = function(message)
        Commands:Handle(message)
    end
end

function Commands:Handle(message)
    local command, rest = trim(message):match("^(%S*)%s*(.-)$")
    command = command:lower()
    if command == "" then
        ns.ui.MainFrame:Toggle()
    elseif command == "sync" then
        if ns.Comm:RequestSync() then
            ns:Print(ns:L("SYNC_REQUESTED"))
        else
            ns:Print(ns:L("SYNC_UNAVAILABLE"))
        end
    elseif command == "version" then
        local peers = ns.Comm:GetPeers()
        if #peers == 0 then
            ns:Print(ns:L("VERSION_NONE"))
        else
            for _, peer in ipairs(peers) do
                ns:Print(ns:L("VERSION_LINE", peer.name, peer.version, peer.protocol)
                    .. (peer.compatible and "" or " |cffff5555(!)|r"))
            end
        end
    elseif command == "reset" then
        ns.ui.MainFrame:ResetPosition()
        ns.ui.MainFrame.frame:Show()
    elseif command == "settings" then
        ns.ui.MainFrame:Initialize()
        ns.ui.MainFrame.frame:Show()
        ns.ui.MainFrame:ShowSettings()
    elseif command == "demo" then
        ns.modules.Demo:Toggle()
        ns.ui.MainFrame:Initialize()
        ns.ui.MainFrame.frame:Show()
    elseif command == "bank" then
        local snapshot, errorCode = ns.modules.Bank:Scan()
        if snapshot then
            ns:Print(ns:L("BANK_SCANNED", snapshot.itemTypeCount or 0))
        else
            ns:Print(errorCode == "not-keeper" and ns:L("BANK_NOT_KEEPER")
                or ns:L("BANK_OPEN_REQUIRED"))
        end
    elseif command == "lang" then
        if rest == "ru" or rest == "ruRU" then ns.Database.db.settings.locale = "ruRU"
        elseif rest == "en" or rest == "enUS" then ns.Database.db.settings.locale = "enUS"
        elseif rest == "uk" or rest == "ukUA" then ns.Database.db.settings.locale = "ukUA"
        end
        ns.ui.MainFrame:Refresh()
    else
        ns:Print("/gh · /gh sync · /gh version · /gh settings · /gh reset · /gh demo · /gh bank · /gh lang ru|en|uk")
    end
end

