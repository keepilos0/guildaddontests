local _, ns = ...

local Database = {}
ns.Database = Database

local entityCollections = {
    "profiles", "news", "requests", "responses", "groups", "applications",
    "tasks", "contributions", "respect", "bankSnapshots", "bankRequests",
    "bankTags", "bankViews", "moderations",
}

local function deepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return seen[value]
    end
    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do
        copy[deepCopy(key, seen)] = deepCopy(child, seen)
    end
    return copy
end

local function randomInstallId()
    local now = ns.GameAPI:Now()
    local player = ns.GameAPI:GetPlayerName():gsub("[^%w]", "")
    return player .. ":" .. tostring(now) .. ":" .. tostring(math.random(100000, 999999))
end

local function newGuildData()
    local data = {
        createdAt = ns.GameAPI:Now(),
        lastMergedAt = 0,
        config = {
            officerRankThreshold = 1,
            requestMinLevel = ns.constants.requestMinLevel,
            maxActiveRequests = ns.constants.maxActiveRequests,
            maxActiveGroups = ns.constants.maxActiveGroups,
            bankKeepers = {},
        },
        roster = {},
        seenOperations = {},
    }
    for _, name in ipairs(entityCollections) do
        data[name] = {}
    end
    return data
end

function Database:Initialize()
    GuildHubClassicDB = GuildHubClassicDB or {}
    GuildHubClassicCharDB = GuildHubClassicCharDB or {}

    local db = GuildHubClassicDB
    if db.schemaVersion and db.schemaVersion > ns.schemaVersion then
        db.readOnly = true
        ns:Print(ns:L("ERROR_NEWER_DB"))
        self.db = db
        self.char = GuildHubClassicCharDB
        return false
    end

    if not db.schemaVersion then
        db.schemaVersion = 0
    end
    if db.schemaVersion < ns.schemaVersion then
        db.migrationBackup = deepCopy(db)
        self:Migrate(db)
    end

    db.settings = db.settings or {
        locale = nil,
        importantNotifications = true,
        demoMode = false,
    }
    db.guilds = db.guilds or {}
    db.installId = db.installId or randomInstallId()
    db.counter = db.counter or 0
    db.errorLog = db.errorLog or {}
    db.readOnly = false

    GuildHubClassicCharDB.window = GuildHubClassicCharDB.window or { x = 0, y = 0 }
    GuildHubClassicCharDB.drafts = GuildHubClassicCharDB.drafts or {}
    self.db = db
    self.char = GuildHubClassicCharDB
    return true
end

function Database:Migrate(db)
    if db.schemaVersion == 0 then
        db.settings = db.settings or {}
        db.guilds = db.guilds or {}
        db.schemaVersion = 1
    end
end

function Database:GetGuildKey()
    if self.db and self.db.settings and self.db.settings.demoMode then
        return "demo:local:GuildHubClassic"
    end
    return ns.GameAPI:GetGuildKey()
end

function Database:GetGuild(create)
    local key = self:GetGuildKey()
    local guild = self.db.guilds[key]
    if not guild and create ~= false and not self.db.readOnly then
        guild = newGuildData()
        guild.key = key
        self.db.guilds[key] = guild
    end
    return guild, key
end

function Database:NewGuildData()
    return newGuildData()
end

function Database:NextId(kind)
    self.db.counter = (self.db.counter or 0) + 1
    return table.concat({ kind, self.db.installId, tostring(self.db.counter) }, ":")
end

function Database:IsReadOnly()
    return self.db and self.db.readOnly
end

function Database:DeepCopy(value)
    return deepCopy(value)
end

function Database:GetSnapshot()
    local guild = self:GetGuild(false)
    if not guild then
        return nil
    end
    local snapshot = {
        key = guild.key,
        config = deepCopy(guild.config),
        roster = deepCopy(guild.roster),
        createdAt = guild.createdAt,
        lastMergedAt = guild.lastMergedAt,
    }
    for _, name in ipairs(entityCollections) do
        snapshot[name] = deepCopy(guild[name] or {})
    end
    return snapshot
end

function Database:GetCollections()
    return entityCollections
end

function Database:LogError(code, detail)
    local log = self.db.errorLog
    log[#log + 1] = {
        at = ns.GameAPI:Now(),
        code = tostring(code or "unknown"),
        detail = tostring(detail or ""),
    }
    while #log > 200 do
        table.remove(log, 1)
    end
end

