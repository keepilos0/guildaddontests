local _, ns = ...

local Addon = ns.Addon
GuildHubClassic = ns

function Addon:OnInitialize()
    ns.Database:Initialize()
    ns.ui.MainFrame:Initialize()
    ns.Comm:Initialize()
    ns.Commands:Register()

    if ns.Database.db.settings.demoMode then
        ns.modules.Demo:Seed()
    end
    if not ns.GameAPI:IsSupportedFlavor() then
        ns:Print(ns:L("CLASSIC_ERA_ONLY"))
    end
    if ns.GameAPI:IsAddOnLoaded("GuildHubClassic_Prototype") then
        ns:Print(ns:L("PROTOTYPE_WARNING"))
    end

    ns.Store:OnChanged(function(kind, entity, source)
        if source == "remote" and ns.Database.db.settings.importantNotifications then
            local player = ns.GameAPI:GetPlayerName()
            if kind == "responses" and entity.target == player and entity.status == "pending" then
                ns:Print(ns:L("NOTIFY_RESPONSE"))
            elseif kind == "applications" and entity.target == player and entity.status == "pending" then
                ns:Print(ns:L("NOTIFY_APPLICATION"))
            elseif kind == "bankRequests" and entity.keeper == player and entity.status == "pending" then
                ns:Print(ns:L("NOTIFY_BANK_REQUEST"))
            elseif entity.owner == player and (entity.status == "accepted"
                or entity.status == "declined" or entity.status == "rejected") then
                ns:Print(ns:L("NOTIFY_DECISION", entity.status))
            end
        end
        if ns.ui.MainFrame.frame and ns.ui.MainFrame.frame:IsShown() then
            ns.ui.MainFrame:Refresh()
        end
    end)

    self:RegisterEvent("PLAYER_LOGIN", "HandlePlayerLogin")
    self:RegisterEvent("GUILD_ROSTER_UPDATE", "HandleRosterUpdate")
    self:RegisterEvent("PLAYER_GUILD_UPDATE", "HandleRosterUpdate")
    self:RegisterEvent("PLAYER_LEVEL_UP", "HandlePlayerLevel")
    self:RegisterEvent("BANKFRAME_OPENED", "HandleBankOpened")
end

function Addon:HandlePlayerLogin()
    ns.modules.Roster:Refresh()
    ns.Store:RunMaintenance()
    ns.GameAPI:After(2, function() ns.Comm:SendHello() end)
    ns.GameAPI:After(4, function() ns.Comm:RequestSync() end)
    ns.GameAPI:NewTicker(60, function() ns.Store:RunMaintenance() end)
end

function Addon:HandleRosterUpdate()
    ns.modules.Roster:Refresh()
    if ns.ui.MainFrame.frame:IsShown() then
        ns.ui.MainFrame:Refresh()
    end
end

function Addon:HandlePlayerLevel(_, newLevel)
    local profile = ns.modules.Profiles:Get()
    if profile then
        ns.Store:Update("profiles", profile.id, { level = tonumber(newLevel) or ns.GameAPI:GetPlayerLevel() })
    end
end

function Addon:HandleBankOpened()
    if ns.ui.MainFrame.frame:IsShown() and ns.ui.MainFrame.selectedTab == "bank" then
        ns.ui.MainFrame:Refresh()
    end
end
