local _, ns = ...

local Roster = ns:RegisterModule("Roster", {})

function Roster:Refresh()
    local guild = ns.Database:GetGuild()
    if ns.Database.db.settings.demoMode then
        return guild.roster
    end
    if not ns.GameAPI:IsInGuild() then
        guild.roster = {}
        return guild.roster
    end

    ns.GameAPI:RequestGuildRoster()
    local previous = guild.roster or {}
    local refreshed = {}
    for _, member in ipairs(ns.GameAPI:GetRosterMembers()) do
        local normalized = ns.GameAPI:NormalizeCharacterName(member.name)
        member.name = normalized
        member.lastSeenAt = member.online and ns.GameAPI:Now()
            or previous[normalized] and previous[normalized].lastSeenAt
        refreshed[normalized] = member
    end

    local now = ns.GameAPI:Now()
    for name, oldMember in pairs(previous) do
        if not refreshed[name] then
            oldMember.departedAt = oldMember.departedAt or now
            refreshed[name] = oldMember
            for _, kind in ipairs({ "requests", "groups" }) do
                for _, entity in pairs(guild[kind] or {}) do
                    if entity.owner == name and entity.status == "active" then
                        entity.status = "archived"
                        entity.closedAt = now
                        entity.closeReason = "left-guild"
                    end
                end
            end
        end
    end
    guild.roster = refreshed
    return refreshed
end

function Roster:List(includeDeparted)
    local result = {}
    local guild = ns.Database:GetGuild()
    for _, member in pairs(guild.roster or {}) do
        if includeDeparted or not member.departedAt then
            result[#result + 1] = member
        end
    end
    table.sort(result, function(a, b)
        if a.online ~= b.online then
            return a.online
        end
        return a.name < b.name
    end)
    return result
end

function Roster:GetStats()
    local total, online = 0, 0
    for _, member in ipairs(self:List(false)) do
        total = total + 1
        if member.online then online = online + 1 end
    end
    return online, total
end

