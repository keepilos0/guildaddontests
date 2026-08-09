local _, ns = ...

local Permissions = {}
ns.Permissions = Permissions

function Permissions:GetRank(characterName)
    return ns.GameAPI:GetGuildRankIndex(characterName or ns.GameAPI:GetPlayerName())
end

function Permissions:IsLeader(characterName)
    local rank = self:GetRank(characterName)
    return rank == 0
end

function Permissions:IsOfficer(characterName)
    if ns.Database.db.settings.demoMode then
        return true
    end
    local rank = self:GetRank(characterName)
    if rank == nil then
        return false
    end
    local guild = ns.Database:GetGuild(false)
    local threshold = guild and guild.config.officerRankThreshold or 1
    return rank <= threshold
end

function Permissions:CanCreate(kind, actor)
    if kind == "news" or kind == "tasks" or kind == "respect"
        or kind == "bankTags" or kind == "bankViews" or kind == "moderations" then
        return self:IsOfficer(actor)
    end
    return true
end

function Permissions:CanEdit(kind, entity, actor)
    actor = actor or ns.GameAPI:GetPlayerName()
    if self:IsOfficer(actor) and (kind == "news" or kind == "tasks"
        or kind == "bankTags" or kind == "bankViews" or kind == "moderations") then
        return true
    end
    return entity and entity.owner == actor
end

function Permissions:CanModerate(actor)
    return self:IsOfficer(actor)
end

function Permissions:CanChangeConfig(actor)
    return self:IsLeader(actor) or ns.Database.db.settings.demoMode
end

