local _, ns = ...

local GameAPI = {}
ns.GameAPI = GameAPI

function GameAPI:GetCapabilities()
    return {
        flavor = self:GetFlavor(),
        capabilityVersion = 1,
        addonMessages = C_ChatInfo ~= nil and C_ChatInfo.SendAddonMessage ~= nil,
        guildRoster = GetNumGuildMembers ~= nil and GetGuildRosterInfo ~= nil,
        containers = (C_Container and C_Container.GetContainerNumSlots ~= nil)
            or GetContainerNumSlots ~= nil,
        groupInvites = C_PartyInfo and C_PartyInfo.InviteUnit ~= nil
            or InviteUnit ~= nil,
    }
end

function GameAPI:GetFlavor()
    if WOW_PROJECT_ID and WOW_PROJECT_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
        return "classic-era"
    end
    return "unsupported"
end

function GameAPI:IsSupportedFlavor()
    return self:GetFlavor() == "classic-era"
end

function GameAPI:GetLocale()
    return GetLocale and GetLocale() or "enUS"
end

function GameAPI:Now()
    return GetServerTime and GetServerTime() or time()
end

function GameAPI:After(delay, callback)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, callback)
    else
        callback()
    end
end

function GameAPI:NewTicker(interval, callback)
    if C_Timer and C_Timer.NewTicker then
        return C_Timer.NewTicker(interval, callback)
    end
    return nil
end

function GameAPI:IsAddOnLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(name)
    elseif IsAddOnLoaded then
        return IsAddOnLoaded(name)
    end
    return false
end

function GameAPI:GetRealmName()
    if GetNormalizedRealmName then
        return GetNormalizedRealmName() or "UnknownRealm"
    end
    return GetRealmName and GetRealmName() or "UnknownRealm"
end

function GameAPI:GetPlayerName()
    local name, realm
    if UnitFullName then
        name, realm = UnitFullName("player")
    else
        name = UnitName and UnitName("player")
    end
    realm = realm and realm ~= "" and realm or self:GetRealmName()
    return (name or "Unknown") .. "-" .. (realm or "UnknownRealm")
end

function GameAPI:NormalizeCharacterName(name)
    if not name or name == "" then
        return nil
    end
    if name:find("-", 1, true) then
        return name
    end
    return name .. "-" .. self:GetRealmName()
end

function GameAPI:GetPlayerLevel()
    return UnitLevel and (UnitLevel("player") or 0) or 0
end

function GameAPI:GetPlayerClass()
    local localized, classFile = UnitClass and UnitClass("player")
    return localized or "", classFile or "UNKNOWN"
end

function GameAPI:GetFaction()
    return UnitFactionGroup and (UnitFactionGroup("player") or "Neutral") or "Neutral"
end

function GameAPI:IsInGuild()
    return IsInGuild and IsInGuild() or false
end

function GameAPI:GetGuildName()
    return GetGuildInfo and GetGuildInfo("player") or nil
end

function GameAPI:GetGuildKey()
    local guildName = self:GetGuildName()
    if not guildName then
        return "noguild:" .. self:GetRealmName() .. ":" .. self:GetFaction()
    end
    return self:GetRealmName() .. ":" .. self:GetFaction() .. ":" .. guildName
end

function GameAPI:RequestGuildRoster()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

function GameAPI:GetRosterMembers()
    local result = {}
    local total = GetNumGuildMembers and GetNumGuildMembers() or 0
    for index = 1, total do
        local name, rankName, rankIndex, level, className, zone, note,
            officerNote, online, status, classFileName, _, _, _, _, _, guid =
            GetGuildRosterInfo(index)
        if name then
            result[#result + 1] = {
                name = name,
                rankName = rankName or "",
                rankIndex = rankIndex or 99,
                level = level or 0,
                className = className or "",
                classFile = classFileName or "UNKNOWN",
                zone = zone or "",
                note = note or "",
                officerNote = officerNote or "",
                online = online and true or false,
                status = status or 0,
                guid = guid,
            }
        end
    end
    return result
end

function GameAPI:GetGuildRankIndex(characterName)
    local shortName = characterName and characterName:match("^[^-]+")
    for _, member in ipairs(self:GetRosterMembers()) do
        local memberShort = member.name and member.name:match("^[^-]+")
        if member.name == characterName or memberShort == shortName then
            return member.rankIndex, member.rankName
        end
    end
    return nil, nil
end

function GameAPI:GetPlayerRankIndex()
    return self:GetGuildRankIndex(self:GetPlayerName())
end

function GameAPI:RegisterAddonPrefix(prefix)
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        return C_ChatInfo.RegisterAddonMessagePrefix(prefix)
    end
    return false
end

function GameAPI:Invite(characterName)
    if C_PartyInfo and C_PartyInfo.InviteUnit then
        C_PartyInfo.InviteUnit(characterName)
        return true
    elseif InviteUnit then
        InviteUnit(characterName)
        return true
    end
    return false
end

function GameAPI:IsBankOpen()
    return BankFrame and BankFrame.IsShown and BankFrame:IsShown() or false
end

function GameAPI:GetContainerNumSlots(container)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(container) or 0
    elseif GetContainerNumSlots then
        return GetContainerNumSlots(container) or 0
    end
    return 0
end

function GameAPI:GetContainerItem(container, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(container, slot)
        if not info then
            return nil
        end
        return {
            itemID = info.itemID,
            count = info.stackCount or 1,
            quality = info.quality,
            link = info.hyperlink,
            icon = info.iconFileID,
        }
    elseif GetContainerItemInfo then
        local icon, count, _, quality, _, _, link, _, _, itemID =
            GetContainerItemInfo(container, slot)
        if not icon and not link then
            return nil
        end
        return {
            itemID = itemID,
            count = count or 1,
            quality = quality,
            link = link,
            icon = icon,
        }
    end
    return nil
end

function GameAPI:GetItemName(itemID, link)
    local name = GetItemInfo and GetItemInfo(link or itemID)
    return name or link or ("item:" .. tostring(itemID or 0))
end

function GameAPI:ScanCurrentBank()
    if not self:IsBankOpen() then
        return nil, "bank-not-open"
    end

    local containers = {}
    local normalBags = NUM_BAG_SLOTS or 4
    for container = 0, normalBags do
        containers[#containers + 1] = container
    end
    containers[#containers + 1] = BANK_CONTAINER or -1
    local bankBags = NUM_BANKBAGSLOTS or 7
    for container = normalBags + 1, normalBags + bankBags do
        containers[#containers + 1] = container
    end

    local aggregated = {}
    for _, container in ipairs(containers) do
        for slot = 1, self:GetContainerNumSlots(container) do
            local item = self:GetContainerItem(container, slot)
            if item and item.itemID then
                local key = tostring(item.itemID)
                local existing = aggregated[key]
                if not existing then
                    existing = {
                        itemID = item.itemID,
                        name = self:GetItemName(item.itemID, item.link),
                        link = item.link,
                        icon = item.icon,
                        quality = item.quality or 0,
                        count = 0,
                    }
                    aggregated[key] = existing
                end
                existing.count = existing.count + (item.count or 1)
            end
        end
    end
    return aggregated
end
