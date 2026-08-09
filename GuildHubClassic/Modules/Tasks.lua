local _, ns = ...

local Tasks = ns:RegisterModule("Tasks", {})

function Tasks:Create(values)
    if not ns.Permissions:IsOfficer() then
        return nil, "permission"
    end
    local cleaned, errorMessage = ns.Validation:Task(values)
    if not cleaned then
        return nil, errorMessage
    end
    cleaned.reported = 0
    cleaned.confirmed = 0
    return ns.Store:Create("tasks", cleaned)
end

function Tasks:Report(taskId, values)
    local task = ns.Store:Get("tasks", taskId)
    if not task or task.status ~= "active" then
        return nil, "not-active"
    end
    local cleaned, errorMessage = ns.Validation:Contribution(values)
    if not cleaned then
        return nil, errorMessage
    end
    cleaned.taskId = taskId
    cleaned.status = "pending"
    local contribution, errorCode = ns.Store:Create("contributions", cleaned)
    if contribution then
        task.reported = (task.reported or 0) + cleaned.amount
    end
    return contribution, errorCode
end

function Tasks:Confirm(contributionId, accepted)
    if not ns.Permissions:IsOfficer() then
        return nil, "permission"
    end
    local contribution = ns.Store:Get("contributions", contributionId)
    if not contribution or contribution.status ~= "pending" then
        return nil, "not-pending"
    end
    local task = ns.Store:Get("tasks", contribution.taskId)
    if not task then
        return nil, "task-missing"
    end
    local status = accepted and "confirmed" or "rejected"
    local updated, errorCode = ns.Store:ControlledUpdate("contributions", contributionId, {
        status = status,
        reviewedBy = ns.GameAPI:GetPlayerName(),
        reviewedAt = ns.GameAPI:Now(),
    })
    if not updated then
        return nil, errorCode
    end
    if accepted then
        task.confirmed = (task.confirmed or 0) + contribution.amount
        ns.Store:Update("tasks", task.id, { confirmed = task.confirmed })
        if (task.respect or 0) > 0 then
            ns.Store:Create("respect", {
                recipient = contribution.owner,
                points = task.respect,
                reason = task.title,
                taskId = task.id,
                contributionId = contribution.id,
                confirmedBy = ns.GameAPI:GetPlayerName(),
            })
        end
    end
    return updated
end

function Tasks:GetRespect(characterName)
    characterName = characterName or ns.GameAPI:GetPlayerName()
    local total = 0
    local history = {}
    for _, entry in pairs(ns.Store:GetCollection("respect") or {}) do
        if entry.recipient == characterName and entry.status == "active" then
            total = total + (tonumber(entry.points) or 0)
            history[#history + 1] = entry
        end
    end
    table.sort(history, function(a, b) return (a.createdAt or 0) > (b.createdAt or 0) end)
    return total, history
end

function Tasks:GetProgress(taskId)
    local reported, confirmed = 0, 0
    for _, contribution in pairs(ns.Store:GetCollection("contributions") or {}) do
        if contribution.taskId == taskId and contribution.status ~= "rejected" then
            reported = reported + (tonumber(contribution.amount) or 0)
            if contribution.status == "confirmed" then
                confirmed = confirmed + (tonumber(contribution.amount) or 0)
            end
        end
    end
    local task = ns.Store:Get("tasks", taskId)
    if task then
        reported = math.max(reported, tonumber(task.reported) or 0)
        confirmed = math.max(confirmed, tonumber(task.confirmed) or 0)
    end
    return reported, confirmed
end

function Tasks:List(includeArchived)
    return ns.Store:List("tasks", includeArchived)
end
