local _, ns = ...

local Requests = ns:RegisterModule("Requests", {})

function Requests:Create(values)
    local guild = ns.Database:GetGuild()
    local minimum = guild.config.requestMinLevel or ns.constants.requestMinLevel
    if ns.GameAPI:GetPlayerLevel() < minimum and not ns.Database.db.settings.demoMode then
        return nil, "level"
    end
    local owner = ns.GameAPI:GetPlayerName()
    local maximum = guild.config.maxActiveRequests or ns.constants.maxActiveRequests
    if ns.Store:CountActive("requests", owner) >= maximum then
        return nil, "request-limit"
    end
    local cleaned, errorMessage = ns.Validation:Request(values)
    if not cleaned then
        return nil, errorMessage
    end
    local now = ns.GameAPI:Now()
    cleaned.expiresAt = now + cleaned.durationHours * 60 * 60
    return ns.Store:Create("requests", cleaned)
end

function Requests:Respond(requestId, message)
    local request = ns.Store:Get("requests", requestId)
    if not request or request.status ~= "active" then
        return nil, "not-active"
    end
    return ns.Store:Create("responses", {
        requestId = requestId,
        target = request.owner,
        message = ns.Validation:Clean(message, 300),
        status = "pending",
    })
end

function Requests:SetResponseStatus(responseId, status)
    if status ~= "accepted" and status ~= "declined" then
        return nil, "invalid"
    end
    return ns.Store:ControlledUpdate("responses", responseId, { status = status })
end

function Requests:Close(requestId, reason)
    return ns.Store:Close("requests", requestId, reason)
end

function Requests:List(includeArchived)
    return ns.Store:List("requests", includeArchived)
end
