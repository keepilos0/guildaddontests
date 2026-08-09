local _, ns = ...

local Demo = ns:RegisterModule("Demo", {})

local function demoName(name)
    return name .. "-DemoRealm"
end

function Demo:IsEnabled()
    return ns.Database.db.settings.demoMode == true
end

function Demo:SetEnabled(enabled)
    ns.Database.db.settings.demoMode = enabled and true or false
    if enabled then
        self:Seed()
    end
    if ns.ui.MainFrame then
        ns.ui.MainFrame:Refresh()
    end
end

function Demo:Toggle()
    self:SetEnabled(not self:IsEnabled())
    ns:Print(ns:L(self:IsEnabled() and "DEMO_ENABLED" or "DEMO_DISABLED"))
end

function Demo:Seed()
    local guild = ns.Database:GetGuild()
    if guild.demoSeeded then
        return
    end
    guild.demoSeeded = true
    guild.roster = {
        [demoName("Arthas")] = { name = demoName("Arthas"), rankName = "Guild Master", rankIndex = 0, level = 60, className = "Warrior", classFile = "WARRIOR", zone = "Stormwind", online = true },
        [demoName("Lunara")] = { name = demoName("Lunara"), rankName = "Officer", rankIndex = 1, level = 60, className = "Druid", classFile = "DRUID", zone = "Moonglade", online = true },
        [demoName("Elaria")] = { name = demoName("Elaria"), rankName = "Member", rankIndex = 3, level = 42, className = "Priest", classFile = "PRIEST", zone = "Dustwallow Marsh", online = true },
        [demoName("Mordek")] = { name = demoName("Mordek"), rankName = "Member", rankIndex = 3, level = 38, className = "Rogue", classFile = "ROGUE", zone = "Tanaris", online = false },
    }
    ns.Store:Create("news", {
        title = "Подготовка к рейду",
        description = "Проверьте задания и список нужных материалов.",
    }, { actor = demoName("Arthas") })
    ns.Store:Create("requests", {
        title = "Элитная цепочка в Пылевых топях",
        description = "Нужна помощь с последним этапом цепочки.",
        category = "help",
        expiresAt = ns.GameAPI:Now() + 24 * 60 * 60,
        durationHours = 24,
    }, { actor = demoName("Elaria") })
    ns.Store:Create("groups", {
        title = "Глубины Чёрной горы",
        description = "Нужны лекарь и два бойца.",
        size = 5,
        roles = "1 healer, 2 damage",
        minLevel = 52,
        maxLevel = 60,
        startAt = ns.GameAPI:Now() + 60 * 60,
        expiresAt = ns.GameAPI:Now() + 3 * 60 * 60,
    }, { actor = demoName("Lunara") })
    ns.Store:Create("tasks", {
        title = "Зелья защиты от огня",
        description = "Собрать 60 зелий для рейда.",
        goal = 60,
        reported = 42,
        confirmed = 30,
        respect = 10,
    }, { actor = demoName("Arthas") })
    ns.Store:Create("respect", {
        recipient = ns.GameAPI:GetPlayerName(),
        points = 18,
        reason = "Помощь новичкам",
        confirmedBy = demoName("Arthas"),
    }, { actor = demoName("Arthas") })
    ns.Store:Create("bankSnapshots", {
        scannedAt = ns.GameAPI:Now(),
        itemTypeCount = 3,
        items = {
            ["14047"] = { itemID = 14047, name = "Руническая ткань", count = 340, quality = 1 },
            ["12363"] = { itemID = 12363, name = "Чародейский кристалл", count = 7, quality = 2 },
            ["13457"] = { itemID = 13457, name = "Зелье защиты от огня", count = 24, quality = 1 },
        },
    }, { actor = demoName("GuildBank") })
    guild.config.bankKeepers[demoName("GuildBank")] = true
end

