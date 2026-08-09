local _, ns = ...

local Store = { listeners = {} }
ns.Store = Store

local function copyFields(target, fields)
    for key, value in pairs(fields or {}) do
        if key ~= "id" and key ~= "owner" and key ~= "createdAt" then
            target[key] = ns.Database:DeepCopy(value)
        end
    end
end

function Store:OnChanged(callback)
    self.listeners[#self.listeners + 1] = callback
end

function Store:Notify(kind, entity, source)
    for _, callback in ipairs(self.listeners) do
        local ok, errorMessage = pcall(callback, kind, entity, source)
        if not ok then
            ns.Database:LogError("listener", errorMessage)
        end
    end
end

function Store:GetCollection(kind)
    local guild = ns.Database:GetGuild()
    return guild and guild[kind] or nil
end

function Store:Get(kind, id)
    local collection = self:GetCollection(kind)
    return collection and collection[id] or nil
end

function Store:List(kind, includeArchived)
    local result = {}
    local collection = self:GetCollection(kind) or {}
    for _, entity in pairs(collection) do
        if includeArchived or entity.status == "active" or entity.status == "pending" then
            result[#result + 1] = entity
        end
    end
    table.sort(result, function(left, right)
        local leftTime = left.updatedAt or left.createdAt or 0
        local rightTime = right.updatedAt or right.createdAt or 0
        if leftTime == rightTime then
            return tostring(left.id) < tostring(right.id)
        end
        return leftTime > rightTime
    end)
    return result
end

function Store:CountActive(kind, owner)
    local count = 0
    for _, entity in pairs(self:GetCollection(kind) or {}) do
        if entity.owner == owner and entity.status == "active" then
            count = count + 1
        end
    end
    return count
end

function Store:Create(kind, fields, options)
    if ns.Database:IsReadOnly() then
        return nil, "read-only"
    end
    local actor = options and options.actor or ns.GameAPI:GetPlayerName()
    if not ns.Permissions:CanCreate(kind, actor) then
        return nil, "permission"
    end
    local collection = self:GetCollection(kind)
    if not collection then
        return nil, "unknown-kind"
    end
    local now = ns.GameAPI:Now()
    local entity = {
        id = ns.Database:NextId(kind),
        kind = kind,
        owner = actor,
        revision = 1,
        createdAt = now,
        updatedAt = now,
        status = fields.status or "active",
    }
    copyFields(entity, fields)
    collection[entity.id] = entity
    local guild = ns.Database:GetGuild()
    guild.lastMergedAt = now
    self:Notify(kind, entity, "local")
    if ns.Comm then
        ns.Comm:BroadcastOperation({ action = "upsert", kind = kind, entity = entity })
    end
    return entity
end

function Store:Update(kind, id, fields, options)
    if ns.Database:IsReadOnly() then
        return nil, "read-only"
    end
    local entity = self:Get(kind, id)
    if not entity then
        return nil, "not-found"
    end
    local actor = options and options.actor or ns.GameAPI:GetPlayerName()
    if not ns.Permissions:CanEdit(kind, entity, actor) then
        return nil, "permission"
    end
    copyFields(entity, fields)
    entity.revision = (entity.revision or 0) + 1
    entity.updatedAt = ns.GameAPI:Now()
    local guild = ns.Database:GetGuild()
    guild.lastMergedAt = entity.updatedAt
    self:Notify(kind, entity, "local")
    if ns.Comm then
        ns.Comm:BroadcastOperation({ action = "upsert", kind = kind, entity = entity })
    end
    return entity
end

function Store:ControlledUpdate(kind, id, fields)
    if ns.Database:IsReadOnly() then
        return nil, "read-only"
    end
    local entity = self:Get(kind, id)
    if not entity then
        return nil, "not-found"
    end
    local actor = ns.GameAPI:GetPlayerName()
    local allowed = ns.Permissions:IsOfficer(actor)
    if kind == "applications" then
        local group = self:Get("groups", entity.groupId)
        allowed = group and group.owner == actor
    elseif kind == "responses" then
        local request = self:Get("requests", entity.requestId)
        allowed = request and request.owner == actor
    elseif kind == "profiles" then
        allowed = entity.mainCharacter == actor
    elseif kind == "bankRequests" then
        allowed = entity.keeper == actor or ns.Permissions:IsOfficer(actor)
    end
    if not allowed then
        return nil, "permission"
    end
    copyFields(entity, fields)
    entity.revision = (entity.revision or 0) + 1
    entity.updatedAt = ns.GameAPI:Now()
    local guild = ns.Database:GetGuild()
    guild.lastMergedAt = entity.updatedAt
    self:Notify(kind, entity, "local")
    if ns.Comm then
        ns.Comm:BroadcastOperation({
            action = "upsert",
            kind = kind,
            entity = entity,
            controller = actor,
        })
    end
    return entity
end

function Store:Close(kind, id, reason)
    local entity = self:Get(kind, id)
    if not entity then
        return nil, "not-found"
    end
    local actor = ns.GameAPI:GetPlayerName()
    local isOwner = entity.owner == actor
    local isOfficer = ns.Permissions:CanModerate(actor)
    if not isOwner and not isOfficer then
        return nil, "permission"
    end
    local fields = {
        status = "archived",
        closedAt = ns.GameAPI:Now(),
        closedBy = actor,
        closeReason = ns.Validation:Clean(reason, 200),
    }
    if isOwner then
        return self:Update(kind, id, fields)
    end

    copyFields(entity, fields)
    entity.revision = (entity.revision or 0) + 1
    entity.updatedAt = ns.GameAPI:Now()
    local moderation = self:Create("moderations", {
        targetKind = kind,
        targetId = id,
        action = "close",
        reason = fields.closeReason,
        targetRevision = entity.revision,
    })
    self:Notify(kind, entity, "local")
    if ns.Comm then
        ns.Comm:BroadcastOperation({ action = "upsert", kind = kind, entity = entity,
            moderationId = moderation and moderation.id,
            controller = not isOwner and actor or nil })
    end
    return entity
end

function Store:MergeEntity(kind, incoming, source)
    if type(incoming) ~= "table" or type(incoming.id) ~= "string"
        or type(incoming.owner) ~= "string" then
        return false
    end
    local collection = self:GetCollection(kind)
    if not collection then
        return false
    end
    local existing = collection[incoming.id]
    local incomingRevision = tonumber(incoming.revision) or 0
    local existingRevision = existing and (tonumber(existing.revision) or 0) or -1
    if existing and incomingRevision < existingRevision then
        return false
    end
    if existing and incomingRevision == existingRevision
        and (tonumber(incoming.updatedAt) or 0) <= (tonumber(existing.updatedAt) or 0) then
        return false
    end
    collection[incoming.id] = ns.Database:DeepCopy(incoming)
    self:Notify(kind, collection[incoming.id], source or "remote")
    return true
end

function Store:ApplyRemote(operation, sender)
    if type(operation) ~= "table" or operation.action ~= "upsert"
        or type(operation.kind) ~= "string" or type(operation.entity) ~= "table" then
        return false, "malformed-operation"
    end
    sender = ns.GameAPI:NormalizeCharacterName(sender)
    local entity = operation.entity
    if operation.controller then
        if operation.controller ~= sender then
            return false, "remote-controller"
        end
        local controllerAllowed = ns.Permissions:IsOfficer(sender)
        if operation.kind == "applications" then
            local group = self:Get("groups", entity.groupId)
            controllerAllowed = group and group.owner == sender
        elseif operation.kind == "responses" then
            local request = self:Get("requests", entity.requestId)
            controllerAllowed = request and request.owner == sender
        elseif operation.kind == "profiles" then
            controllerAllowed = entity.mainCharacter == sender
        elseif operation.kind == "bankRequests" then
            controllerAllowed = entity.keeper == sender or ns.Permissions:IsOfficer(sender)
        end
        if not controllerAllowed then
            return false, "remote-controller-permission"
        end
        return self:MergeEntity(operation.kind, entity, "remote")
    end
    local officerOwned = operation.kind == "news" or operation.kind == "tasks"
        or operation.kind == "respect" or operation.kind == "bankTags"
        or operation.kind == "bankViews" or operation.kind == "moderations"
    if officerOwned then
        if not ns.Permissions:IsOfficer(sender) then
            return false, "remote-permission"
        end
    elseif entity.owner ~= sender then
        return false, "remote-owner"
    end
    return self:MergeEntity(operation.kind, entity, "remote")
end

function Store:MergeSnapshot(snapshot, sender)
    if type(snapshot) ~= "table" or snapshot.key ~= ns.Database:GetGuildKey() then
        return 0, "wrong-guild"
    end
    local guild = ns.Database:GetGuild()
    local merged = 0
    if ns.Permissions:IsOfficer(sender) and type(snapshot.config) == "table" then
        guild.config = ns.Database:DeepCopy(snapshot.config)
    end
    for _, kind in ipairs(ns.Database:GetCollections()) do
        local collection = snapshot[kind]
        if type(collection) == "table" then
            for _, entity in pairs(collection) do
                if self:MergeEntity(kind, entity, "snapshot") then
                    merged = merged + 1
                end
            end
        end
    end
    guild.lastMergedAt = ns.GameAPI:Now()
    return merged
end

function Store:RunMaintenance()
    local now = ns.GameAPI:Now()
    local guild = ns.Database:GetGuild(false)
    if not guild then
        return
    end
    for _, request in pairs(guild.requests or {}) do
        if request.status == "active" and request.expiresAt and request.expiresAt <= now then
            request.status = "archived"
            request.closedAt = now
            request.closeReason = "expired"
        end
    end
    for _, group in pairs(guild.groups or {}) do
        if group.status == "active" and group.startAt
            and group.startAt + ns.constants.groupArchiveDelaySeconds <= now then
            group.status = "archived"
            group.closedAt = now
            group.closeReason = "expired"
        end
    end
    for _, kind in ipairs({ "requests", "groups", "responses", "applications", "moderations" }) do
        local collection = guild[kind] or {}
        for id, entity in pairs(collection) do
            local archivedAt = entity.closedAt or (entity.status == "archived" and entity.updatedAt)
            if archivedAt and archivedAt + ns.constants.archiveRetentionSeconds <= now then
                collection[id] = nil
            end
        end
    end
end
