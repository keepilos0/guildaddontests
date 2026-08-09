local _, ns = ...

local Groups = ns:RegisterModule("Groups", {})

function Groups:Create(values)
    local guild = ns.Database:GetGuild()
    local minimum = guild.config.requestMinLevel or ns.constants.requestMinLevel
    if ns.GameAPI:GetPlayerLevel() < minimum and not ns.Database.db.settings.demoMode then
        return nil, "level"
    end
    local owner = ns.GameAPI:GetPlayerName()
    local maximum = guild.config.maxActiveGroups or ns.constants.maxActiveGroups
    if ns.Store:CountActive("groups", owner) >= maximum then
        return nil, "group-limit"
    end
    local cleaned, errorMessage = ns.Validation:Group(values)
    if not cleaned then
        return nil, errorMessage
    end
    cleaned.expiresAt = cleaned.startAt + ns.constants.groupArchiveDelaySeconds
    return ns.Store:Create("groups", cleaned)
end

function Groups:Apply(groupId, role, comment)
    local group = ns.Store:Get("groups", groupId)
    if not group or group.status ~= "active" then
        return nil, "not-active"
    end
    return ns.Store:Create("applications", {
        groupId = groupId,
        target = group.owner,
        role = ns.Validation:Clean(role, 40),
        comment = ns.Validation:Clean(comment, 200),
        status = "pending",
    })
end

function Groups:SetApplicationStatus(applicationId, status)
    if status ~= "accepted" and status ~= "declined" then
        return nil, "invalid"
    end
    return ns.Store:ControlledUpdate("applications", applicationId, { status = status })
end

function Groups:Invite(applicationId)
    local application = ns.Store:Get("applications", applicationId)
    local group = application and ns.Store:Get("groups", application.groupId)
    if not application or not group or group.owner ~= ns.GameAPI:GetPlayerName()
        or application.status ~= "accepted" then
        return false, "permission"
    end
    return ns.GameAPI:Invite(application.owner)
end

function Groups:Close(groupId, reason)
    return ns.Store:Close("groups", groupId, reason)
end

function Groups:List(includeArchived)
    return ns.Store:List("groups", includeArchived)
end
