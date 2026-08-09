local _, ns = ...

local Bank = ns:RegisterModule("Bank", {})

function Bank:IsKeeper(characterName)
    local guild = ns.Database:GetGuild()
    characterName = characterName or ns.GameAPI:GetPlayerName()
    return guild.config.bankKeepers[characterName] == true
        or ns.Database.db.settings.demoMode
end

function Bank:SetKeeper(characterName, enabled)
    if not ns.Permissions:IsOfficer() then
        return false, "permission"
    end
    characterName = ns.GameAPI:NormalizeCharacterName(characterName)
    if not characterName then
        return false, "invalid"
    end
    local guild = ns.Database:GetGuild()
    guild.config.bankKeepers[characterName] = enabled and true or nil
    ns.Comm:BroadcastConfig("bankKeepers", guild.config.bankKeepers)
    return true
end

function Bank:GetSnapshot(characterName)
    characterName = characterName or ns.GameAPI:GetPlayerName()
    for _, snapshot in pairs(ns.Store:GetCollection("bankSnapshots") or {}) do
        if snapshot.owner == characterName then
            return snapshot
        end
    end
    return nil
end

function Bank:Scan()
    local actor = ns.GameAPI:GetPlayerName()
    if not self:IsKeeper(actor) then
        return nil, "not-keeper"
    end
    local items, errorMessage = ns.GameAPI:ScanCurrentBank()
    if not items then
        return nil, errorMessage
    end
    local count = 0
    for _ in pairs(items) do count = count + 1 end
    local existing = self:GetSnapshot(actor)
    if existing then
        return ns.Store:Update("bankSnapshots", existing.id, {
            items = items,
            itemTypeCount = count,
            scannedAt = ns.GameAPI:Now(),
        })
    end
    return ns.Store:Create("bankSnapshots", {
        items = items,
        itemTypeCount = count,
        scannedAt = ns.GameAPI:Now(),
    })
end

function Bank:SetTags(itemID, tags, comment)
    if not ns.Permissions:IsOfficer() then
        return nil, "permission"
    end
    local existing
    for _, entry in pairs(ns.Store:GetCollection("bankTags") or {}) do
        if entry.itemID == itemID then existing = entry break end
    end
    local fields = {
        itemID = itemID,
        tags = tags or {},
        comment = ns.Validation:Clean(comment, 300),
    }
    if existing then
        return ns.Store:Update("bankTags", existing.id, fields)
    end
    return ns.Store:Create("bankTags", fields)
end

function Bank:CreateView(name, filters)
    if not ns.Permissions:IsOfficer() then
        return nil, "permission"
    end
    name = ns.Validation:Clean(name, 40)
    if name == "" then return nil, "invalid" end
    return ns.Store:Create("bankViews", { name = name, filters = filters or {} })
end

function Bank:ListItems(filter)
    local tagMap = {}
    for _, entry in pairs(ns.Store:GetCollection("bankTags") or {}) do
        tagMap[tostring(entry.itemID)] = entry
    end
    local result = {}
    for _, snapshot in pairs(ns.Store:GetCollection("bankSnapshots") or {}) do
        if snapshot.status == "active" then
            for key, item in pairs(snapshot.items or {}) do
                local tags = tagMap[key]
                local row = ns.Database:DeepCopy(item)
                row.owner = snapshot.owner
                row.scannedAt = snapshot.scannedAt
                row.tags = tags and tags.tags or {}
                row.comment = tags and tags.comment or ""
                local include = true
                if filter and filter.tag then
                    include = false
                    for _, tag in ipairs(row.tags) do
                        if tag == filter.tag then include = true break end
                    end
                end
                if include then result[#result + 1] = row end
            end
        end
    end
    table.sort(result, function(a, b)
        if (a.name or "") == (b.name or "") then return a.owner < b.owner end
        return (a.name or "") < (b.name or "")
    end)
    return result
end

function Bank:RequestItem(item, count)
    if not item or not item.owner then return nil, "invalid" end
    return ns.Store:Create("bankRequests", {
        itemID = item.itemID,
        itemName = item.name,
        count = math.max(1, math.floor(tonumber(count) or 1)),
        keeper = item.owner,
        status = "pending",
    })
end

function Bank:SetRequestStatus(requestId, status)
    if status ~= "accepted" and status ~= "declined" and status ~= "fulfilled" then
        return nil, "invalid"
    end
    return ns.Store:ControlledUpdate("bankRequests", requestId, {
        status = status,
        reviewedBy = ns.GameAPI:GetPlayerName(),
        reviewedAt = ns.GameAPI:Now(),
    })
end
