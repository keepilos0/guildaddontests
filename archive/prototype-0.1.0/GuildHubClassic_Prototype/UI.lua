local ADDON_NAME = ...
local Data = GuildHubClassicPrototypeData

local Addon = CreateFrame("Frame")
GuildHubClassicPrototype = Addon

local COLORS = {
    gold = { 0.90, 0.72, 0.30 },
    paleGold = { 1.00, 0.88, 0.54 },
    cream = { 0.93, 0.86, 0.70 },
    muted = { 0.65, 0.60, 0.50 },
    green = { 0.32, 0.78, 0.38 },
    blue = { 0.35, 0.68, 0.95 },
    red = { 0.90, 0.28, 0.22 },
    brown = { 0.20, 0.12, 0.06 },
    panel = { 0.075, 0.055, 0.035, 0.96 },
    panelLight = { 0.13, 0.09, 0.045, 0.96 },
    border = { 0.55, 0.39, 0.16, 1.0 },
}

local ui = {
    panels = {},
    tabs = {},
    selectedTab = 1,
}

local function CreateBackdropFrame(frameType, name, parent)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    return CreateFrame(frameType or "Frame", name, parent, template)
end

local function ApplyBackdrop(frame, background, border)
    if not frame.SetBackdrop then
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(unpack(background or COLORS.panel))
    frame:SetBackdropBorderColor(unpack(border or COLORS.border))
end

local function AddText(parent, text, fontObject, color, justify)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(fontObject or GameFontNormal)
    label:SetText(text or "")
    label:SetTextColor(unpack(color or COLORS.cream))
    label:SetJustifyH(justify or "LEFT")
    label:SetJustifyV("MIDDLE")
    return label
end

local function AddIcon(parent, path, size)
    local holder = CreateBackdropFrame("Frame", nil, parent)
    holder:SetSize(size, size)
    ApplyBackdrop(holder, { 0.02, 0.02, 0.02, 1 }, { 0.50, 0.38, 0.17, 1 })

    local texture = holder:CreateTexture(nil, "ARTWORK")
    texture:SetPoint("TOPLEFT", 4, -4)
    texture:SetPoint("BOTTOMRIGHT", -4, 4)
    texture:SetTexture(path)
    texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    holder.texture = texture
    return holder
end

local function ShowToast(message)
    if not ui.toast then
        return
    end

    ui.toast.text:SetText(message)
    ui.toast:Show()
    ui.toast.token = (ui.toast.token or 0) + 1
    local token = ui.toast.token
    C_Timer.After(2.3, function()
        if ui.toast and ui.toast.token == token then
            ui.toast:Hide()
        end
    end)
end

local function CreateButton(parent, label, width, onClick, compact)
    local button = CreateBackdropFrame("Button", nil, parent)
    button:SetSize(width or 120, compact and 24 or 28)
    ApplyBackdrop(button, { 0.19, 0.11, 0.045, 1 }, { 0.72, 0.51, 0.19, 1 })

    local text = AddText(button, label, compact and GameFontNormalSmall or GameFontNormal, COLORS.paleGold, "CENTER")
    text:SetPoint("TOPLEFT", 7, -2)
    text:SetPoint("BOTTOMRIGHT", -7, 2)
    button.text = text

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.90, 0.66, 0.20, 0.13)

    button:SetScript("OnMouseDown", function(self)
        self.text:SetPoint("TOPLEFT", 8, -3)
        self.text:SetPoint("BOTTOMRIGHT", -6, 1)
    end)
    button:SetScript("OnMouseUp", function(self)
        self.text:SetPoint("TOPLEFT", 7, -2)
        self.text:SetPoint("BOTTOMRIGHT", -7, 2)
    end)
    button:SetScript("OnClick", onClick or function()
        ShowToast("Это действие появится в рабочей версии")
    end)
    return button
end

local function CreatePanel(parent, x, y, width, height, title, subtitle)
    local panel = CreateBackdropFrame("Frame", nil, parent)
    panel:SetPoint("TOPLEFT", x, -y)
    panel:SetSize(width, height)
    ApplyBackdrop(panel, COLORS.panel, COLORS.border)

    local titleBar = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
    titleBar:SetPoint("TOPLEFT", 4, -4)
    titleBar:SetPoint("TOPRIGHT", -4, -4)
    titleBar:SetHeight(29)
    titleBar:SetColorTexture(0.24, 0.14, 0.055, 0.90)

    local topLine = panel:CreateTexture(nil, "ARTWORK")
    topLine:SetPoint("TOPLEFT", 5, -33)
    topLine:SetPoint("TOPRIGHT", -5, -33)
    topLine:SetHeight(1)
    topLine:SetColorTexture(0.72, 0.49, 0.17, 0.55)

    local heading = AddText(panel, title, GameFontNormal, COLORS.gold)
    heading:SetPoint("TOPLEFT", 13, -8)
    heading:SetHeight(20)
    panel.heading = heading

    if subtitle then
        local sub = AddText(panel, subtitle, GameFontNormalSmall, COLORS.muted, "RIGHT")
        sub:SetPoint("TOPRIGHT", -12, -8)
        sub:SetHeight(20)
    end

    return panel
end

local function AddDivider(parent, y, left, right)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", left or 10, y)
    line:SetPoint("TOPRIGHT", right or -10, y)
    line:SetHeight(1)
    line:SetColorTexture(0.44, 0.31, 0.13, 0.45)
    return line
end

local function ClassColor(class)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color then
        return color.r, color.g, color.b
    end
    return 0.93, 0.86, 0.70
end

local function SetClassText(label, text, class)
    local r, g, b = ClassColor(class)
    label:SetText(text)
    label:SetTextColor(r, g, b)
end

local function CreateProgress(parent, width, value, maximum)
    local bar = CreateBackdropFrame("StatusBar", nil, parent)
    bar:SetSize(width, 12)
    ApplyBackdrop(bar, { 0.025, 0.018, 0.01, 1 }, { 0.35, 0.26, 0.12, 1 })
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.72, 0.48, 0.12, 1)
    bar:SetMinMaxValues(0, maximum)
    bar:SetValue(value)

    local shine = bar:CreateTexture(nil, "OVERLAY")
    shine:SetPoint("TOPLEFT", 3, -3)
    shine:SetPoint("TOPRIGHT", -3, -3)
    shine:SetHeight(2)
    shine:SetColorTexture(1, 0.82, 0.35, 0.28)
    return bar
end

local function BuildOverview(parent)
    local news = CreatePanel(parent, 0, 0, 570, 209, "ВЕСТИ ГИЛЬДИИ", "обновлено сегодня")

    for index, item in ipairs(Data.news) do
        local y = -43 - ((index - 1) * 78)
        local icon = AddIcon(news, item.icon, 42)
        icon:SetPoint("TOPLEFT", 13, y)

        local title = AddText(news, item.title, GameFontNormal, COLORS.paleGold)
        title:SetPoint("TOPLEFT", 64, y - 1)
        title:SetPoint("TOPRIGHT", -14, y - 1)
        title:SetHeight(18)

        local body = AddText(news, item.text, GameFontNormalSmall, COLORS.cream)
        body:SetPoint("TOPLEFT", 64, y - 20)
        body:SetPoint("TOPRIGHT", -14, y - 20)
        body:SetHeight(30)
        body:SetJustifyV("TOP")
        body:SetWordWrap(true)

        local meta = AddText(news, item.meta, GameFontNormalSmall, COLORS.muted)
        meta:SetPoint("TOPLEFT", 64, y - 52)
        meta:SetHeight(15)

        if index < #Data.news then
            AddDivider(news, y - 70, 13, -13)
        end
    end

    local requests = CreatePanel(parent, 0, 220, 570, 235, "ОТКРЫТЫЕ ЗАПРОСЫ", #Data.requests .. " активных")
    for index, item in ipairs(Data.requests) do
        local y = -43 - ((index - 1) * 61)
        local name = AddText(requests, "", GameFontNormal)
        name:SetPoint("TOPLEFT", 14, y)
        name:SetSize(115, 18)
        SetClassText(name, item.name, item.class)

        local level = AddText(requests, "ур. " .. item.level, GameFontNormalSmall, COLORS.muted)
        level:SetPoint("TOPLEFT", 14, y - 19)
        level:SetSize(80, 16)

        local tag = AddText(requests, item.tag, GameFontNormalSmall, COLORS.gold)
        tag:SetPoint("TOPLEFT", 83, y - 19)
        tag:SetSize(90, 16)

        local body = AddText(requests, item.text, GameFontNormalSmall, COLORS.cream)
        body:SetPoint("TOPLEFT", 138, y - 1)
        body:SetPoint("TOPRIGHT", -105, y - 1)
        body:SetHeight(39)
        body:SetWordWrap(true)
        body:SetJustifyV("TOP")

        local action = CreateButton(requests, "Помогу", 82, function(button)
            button.text:SetText("Отправлено")
            button:Disable()
            button:SetAlpha(0.65)
            ShowToast("Отклик отмечен — это демонстрация")
        end, true)
        action:SetPoint("TOPRIGHT", -13, y - 7)

        if index < #Data.requests then
            AddDivider(requests, y - 54, 13, -13)
        end
    end

    local contribution = CreatePanel(parent, 582, 0, 318, 142, "ВАШ ВКЛАД", "этот сезон")
    local score = AddText(contribution, "248", GameFontHighlightLarge, COLORS.paleGold)
    score:SetPoint("TOPLEFT", 15, -44)
    score:SetSize(80, 30)
    local scoreLabel = AddText(contribution, "репутации гильдии", GameFontNormalSmall, COLORS.muted)
    scoreLabel:SetPoint("TOPLEFT", 82, -49)
    scoreLabel:SetSize(170, 18)
    local rank = AddText(contribution, "До звания «Опора гильдии»", GameFontNormalSmall, COLORS.cream)
    rank:SetPoint("TOPLEFT", 15, -82)
    rank:SetSize(210, 18)
    local numbers = AddText(contribution, "248 / 300", GameFontNormalSmall, COLORS.gold, "RIGHT")
    numbers:SetPoint("TOPRIGHT", -14, -82)
    numbers:SetSize(80, 18)
    local progress = CreateProgress(contribution, 286, 248, 300)
    progress:SetPoint("TOPLEFT", 15, -105)

    local event = CreatePanel(parent, 582, 153, 318, 143, "БЛИЖАЙШЕЕ СОБЫТИЕ", "через 1 день")
    local eventIcon = AddIcon(event, "Interface\\Icons\\INV_Helmet_08", 48)
    eventIcon:SetPoint("TOPLEFT", 14, -45)
    local eventTitle = AddText(event, "Огненные Недра", GameFontNormal, COLORS.paleGold)
    eventTitle:SetPoint("TOPLEFT", 74, -45)
    eventTitle:SetSize(190, 18)
    local eventTime = AddText(event, "Суббота · 19:30", GameFontNormalSmall, COLORS.cream)
    eventTime:SetPoint("TOPLEFT", 74, -66)
    eventTime:SetSize(190, 17)
    local eventCount = AddText(event, "32 / 40 подтвердили", GameFontNormalSmall, COLORS.muted)
    eventCount:SetPoint("TOPLEFT", 74, -86)
    eventCount:SetSize(190, 17)
    local eventButton = CreateButton(event, "Я буду", 94, function(button)
        button.text:SetText("Вы идёте")
        ShowToast("Участие подтверждено — это демонстрация")
    end, true)
    eventButton:SetPoint("BOTTOMRIGHT", -13, 12)

    local needs = CreatePanel(parent, 582, 307, 318, 148, "СЕЙЧАС НУЖНЫ", "доска объявлений")
    local entries = {
        { "Танки 55–60 уровня", "2 места", COLORS.red },
        { "Алхимики с редкими рецептами", "3 места", COLORS.blue },
        { "Материалы для рейда", "67%", COLORS.green },
    }
    for index, entry in ipairs(entries) do
        local y = -45 - ((index - 1) * 31)
        local dot = needs:CreateTexture(nil, "ARTWORK")
        dot:SetSize(6, 6)
        dot:SetPoint("TOPLEFT", 15, y - 6)
        dot:SetColorTexture(unpack(entry[3]))
        local label = AddText(needs, entry[1], GameFontNormalSmall, COLORS.cream)
        label:SetPoint("TOPLEFT", 29, y)
        label:SetSize(205, 18)
        local value = AddText(needs, entry[2], GameFontNormalSmall, COLORS.gold, "RIGHT")
        value:SetPoint("TOPRIGHT", -14, y)
        value:SetSize(72, 18)
    end
end

local function BuildMembers(parent)
    local panel = CreatePanel(parent, 0, 0, 900, 455, "УЧАСТНИКИ ГИЛЬДИИ", Data.guild.online .. " в сети · тестовый список")

    local search = CreateBackdropFrame("EditBox", nil, panel)
    search:SetSize(245, 27)
    search:SetPoint("TOPLEFT", 14, -41)
    ApplyBackdrop(search, { 0.025, 0.02, 0.012, 1 }, { 0.42, 0.31, 0.14, 1 })
    search:SetFontObject(GameFontHighlightSmall)
    search:SetTextInsets(9, 9, 0, 0)
    search:SetAutoFocus(false)
    search:SetText("Поиск появится в рабочей версии")
    search:SetTextColor(unpack(COLORS.muted))
    search:SetScript("OnEditFocusGained", function(self)
        self:ClearFocus()
        ShowToast("Поиск пока работает только визуально")
    end)

    local profile = CreateButton(panel, "+ Мой профиль", 128, function()
        ShowToast("Здесь будет карточка вашего персонажа")
    end)
    profile:SetPoint("TOPRIGHT", -13, -40)

    local columns = {
        { "ИГРОК", 16, 190 },
        { "УРОВЕНЬ", 211, 80 },
        { "КЛАСС", 305, 145 },
        { "МЕСТО", 466, 185 },
        { "СТАТУС", 665, 210 },
    }
    for _, column in ipairs(columns) do
        local label = AddText(panel, column[1], GameFontNormalSmall, COLORS.gold)
        label:SetPoint("TOPLEFT", column[2], -82)
        label:SetSize(column[3], 18)
    end
    AddDivider(panel, -103, 13, -13)

    for index, member in ipairs(Data.members) do
        local y = -111 - ((index - 1) * 39)
        if index % 2 == 0 then
            local shade = panel:CreateTexture(nil, "BACKGROUND", nil, 2)
            shade:SetPoint("TOPLEFT", 7, y + 2)
            shade:SetPoint("TOPRIGHT", -7, y + 2)
            shade:SetHeight(36)
            shade:SetColorTexture(0.25, 0.16, 0.065, 0.16)
        end

        local online = panel:CreateTexture(nil, "ARTWORK")
        online:SetSize(7, 7)
        online:SetPoint("TOPLEFT", 17, y - 12)
        online:SetColorTexture(unpack(member.online and COLORS.green or COLORS.muted))

        local name = AddText(panel, "", GameFontNormal)
        name:SetPoint("TOPLEFT", 31, y - 4)
        name:SetSize(165, 27)
        SetClassText(name, member.name, member.class)

        local level = AddText(panel, tostring(member.level), GameFontNormal, COLORS.cream, "CENTER")
        level:SetPoint("TOPLEFT", 211, y - 4)
        level:SetSize(80, 27)

        local class = AddText(panel, member.className, GameFontNormalSmall)
        class:SetPoint("TOPLEFT", 305, y - 4)
        class:SetSize(145, 27)
        SetClassText(class, member.className, member.class)

        local zone = AddText(panel, member.zone, GameFontNormalSmall, COLORS.cream)
        zone:SetPoint("TOPLEFT", 466, y - 4)
        zone:SetSize(185, 27)

        local statusColor = member.status == "Готова помочь" and COLORS.green
            or member.status == "Готов к рейду" and COLORS.green
            or member.status == "Ищет группу" and COLORS.blue
            or COLORS.muted
        local status = AddText(panel, member.status, GameFontNormalSmall, statusColor)
        status:SetPoint("TOPLEFT", 665, y - 4)
        status:SetSize(210, 27)
    end
end

local function BuildGroups(parent)
    for index, group in ipairs(Data.groups) do
        local y = (index - 1) * 148
        local card = CreatePanel(parent, 0, y, 900, 136, group.title:upper(), group.difficulty)
        local icon = AddIcon(card, group.icon, 58)
        icon:SetPoint("TOPLEFT", 15, -48)

        local time = AddText(card, group.time, GameFontNormal, COLORS.paleGold)
        time:SetPoint("TOPLEFT", 88, -47)
        time:SetSize(220, 20)
        local lead = AddText(card, "Организатор: " .. group.leader, GameFontNormalSmall, COLORS.muted)
        lead:SetPoint("TOPLEFT", 88, -71)
        lead:SetSize(220, 18)
        local need = AddText(card, group.need, GameFontNormalSmall, COLORS.cream)
        need:SetPoint("TOPLEFT", 88, -94)
        need:SetSize(390, 18)

        local countLabel = AddText(card, "Состав группы", GameFontNormalSmall, COLORS.muted, "CENTER")
        countLabel:SetPoint("TOPRIGHT", -180, -47)
        countLabel:SetSize(120, 18)
        local count = AddText(card, group.members, GameFontHighlightLarge, COLORS.gold, "CENTER")
        count:SetPoint("TOPRIGHT", -180, -69)
        count:SetSize(120, 30)

        local join = CreateButton(card, "Присоединиться", 146, function(button)
            button.text:SetText("Заявка отправлена")
            button:Disable()
            button:SetAlpha(0.68)
            ShowToast("Заявка отмечена — это демонстрация")
        end)
        join:SetPoint("RIGHT", -17, -12)
    end
end

local function BuildTasks(parent)
    for index, task in ipairs(Data.tasks) do
        local column = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        local x = column * 456
        local y = row * 228
        local card = CreatePanel(parent, x, y, 444, 216, task.title:upper(), task.deadline)

        local icon = AddIcon(card, task.icon, 48)
        icon:SetPoint("TOPLEFT", 15, -47)
        local body = AddText(card, task.text, GameFontNormalSmall, COLORS.cream)
        body:SetPoint("TOPLEFT", 76, -48)
        body:SetPoint("TOPRIGHT", -15, -48)
        body:SetHeight(38)
        body:SetWordWrap(true)
        body:SetJustifyV("TOP")

        local progressLabel = AddText(card, "Прогресс", GameFontNormalSmall, COLORS.muted)
        progressLabel:SetPoint("TOPLEFT", 15, -111)
        progressLabel:SetSize(100, 18)
        local progressValue = AddText(card, task.progress .. " / " .. task.goal, GameFontNormalSmall, COLORS.gold, "RIGHT")
        progressValue:SetPoint("TOPRIGHT", -15, -111)
        progressValue:SetSize(100, 18)
        local bar = CreateProgress(card, 414, task.progress, task.goal)
        bar:SetPoint("TOPLEFT", 15, -134)

        local reward = AddText(card, task.reward, GameFontNormalSmall, COLORS.green)
        reward:SetPoint("BOTTOMLEFT", 16, 18)
        reward:SetSize(135, 20)
        local action = CreateButton(card, "Участвовать", 116, function(button)
            button.text:SetText("Вы участвуете")
            ShowToast("Участие отмечено — это демонстрация")
        end, true)
        action:SetPoint("BOTTOMRIGHT", -14, 15)
    end
end

local function BuildBank(parent)
    local panel = CreatePanel(parent, 0, 0, 900, 455, "ВИРТУАЛЬНЫЙ БАНК", "снимок · обновлено 12 минут назад")

    local info = AddText(panel, "Предметы банковских персонажей — только просмотр", GameFontNormalSmall, COLORS.muted)
    info:SetPoint("TOPLEFT", 15, -45)
    info:SetSize(370, 24)
    local request = CreateButton(panel, "Запросить предмет", 145, function()
        ShowToast("Форма запроса появится в рабочей версии")
    end)
    request:SetPoint("TOPRIGHT", -14, -41)

    local columns = {
        { "ПРЕДМЕТ", 67, 345 },
        { "КОЛ-ВО", 458, 80 },
        { "ХРАНИТСЯ У", 565, 170 },
        { "ОБНОВЛЕНО", 750, 125 },
    }
    for _, column in ipairs(columns) do
        local label = AddText(panel, column[1], GameFontNormalSmall, COLORS.gold)
        label:SetPoint("TOPLEFT", column[2], -83)
        label:SetSize(column[3], 18)
    end
    AddDivider(panel, -104, 13, -13)

    for index, item in ipairs(Data.bank) do
        local y = -115 - ((index - 1) * 53)
        local icon = AddIcon(panel, item.icon, 39)
        icon:SetPoint("TOPLEFT", 15, y)

        local quality = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality]
        local color = quality and { quality.r, quality.g, quality.b } or COLORS.cream
        local name = AddText(panel, item.name, GameFontNormal, color)
        name:SetPoint("TOPLEFT", 67, y - 4)
        name:SetSize(345, 30)

        local count = AddText(panel, tostring(item.count), GameFontNormal, COLORS.cream, "CENTER")
        count:SetPoint("TOPLEFT", 458, y - 4)
        count:SetSize(80, 30)

        local owner = AddText(panel, item.owner, GameFontNormalSmall, COLORS.cream)
        owner:SetPoint("TOPLEFT", 565, y - 4)
        owner:SetSize(170, 30)

        local updated = AddText(panel, item.updated, GameFontNormalSmall, COLORS.muted)
        updated:SetPoint("TOPLEFT", 750, y - 4)
        updated:SetSize(125, 30)

        if index < #Data.bank then
            AddDivider(panel, y - 46, 13, -13)
        end
    end
end

local function SelectTab(index)
    ui.selectedTab = index
    for tabIndex, panel in ipairs(ui.panels) do
        panel:SetShown(tabIndex == index)
        local tab = ui.tabs[tabIndex]
        if tabIndex == index then
            tab.background:SetColorTexture(0.34, 0.20, 0.07, 0.98)
            tab.text:SetTextColor(unpack(COLORS.paleGold))
            tab.bottomLine:Show()
        else
            tab.background:SetColorTexture(0.10, 0.065, 0.035, 0.98)
            tab.text:SetTextColor(unpack(COLORS.muted))
            tab.bottomLine:Hide()
        end
    end
end

local function UpdateGuildHeader()
    if not ui.guildName then
        return
    end

    local realGuildName = GetGuildInfo and GetGuildInfo("player")
    ui.guildName:SetText(realGuildName or Data.guild.name)
    local playerName = UnitName and UnitName("player") or "Игрок"
    ui.playerLine:SetText("Добро пожаловать, " .. (playerName or "Игрок") .. " · визуальный прототип")
end

local function SavePosition(frame)
    local x, y = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if x and y and parentX and parentY then
        GuildHubClassicPrototypeDB.x = x - parentX
        GuildHubClassicPrototypeDB.y = y - parentY
    end
end

local function ResetPosition()
    if not ui.frame then
        return
    end
    GuildHubClassicPrototypeDB.x = 0
    GuildHubClassicPrototypeDB.y = 0
    ui.frame:ClearAllPoints()
    ui.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    ShowToast("Положение окна сброшено")
end

local function BuildUI()
    if ui.frame then
        return
    end

    local frame = CreateBackdropFrame("Frame", "GuildHubClassicPrototypeFrame", UIParent)
    frame:SetSize(940, 640)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)
    frame:SetScript("OnShow", UpdateGuildHeader)
    ApplyBackdrop(frame, { 0.035, 0.025, 0.015, 0.985 }, { 0.76, 0.55, 0.22, 1 })
    ui.frame = frame

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", GuildHubClassicPrototypeDB.x or 0, GuildHubClassicPrototypeDB.y or 0)

    local innerBorder = CreateBackdropFrame("Frame", nil, frame)
    innerBorder:SetPoint("TOPLEFT", 7, -7)
    innerBorder:SetPoint("BOTTOMRIGHT", -7, 7)
    ApplyBackdrop(innerBorder, { 0, 0, 0, 0 }, { 0.25, 0.17, 0.07, 1 })
    innerBorder:EnableMouse(false)

    local header = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    header:SetPoint("TOPLEFT", 10, -10)
    header:SetPoint("TOPRIGHT", -10, -10)
    header:SetHeight(78)
    header:SetTexture("Interface\\QuestFrame\\QuestBG")
    header:SetTexCoord(0.04, 0.96, 0.07, 0.29)
    header:SetVertexColor(0.42, 0.27, 0.11, 0.82)

    local headerShade = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    headerShade:SetPoint("TOPLEFT", 10, -10)
    headerShade:SetPoint("TOPRIGHT", -10, -10)
    headerShade:SetHeight(78)
    headerShade:SetColorTexture(0.06, 0.035, 0.015, 0.48)

    local crest = AddIcon(frame, "Interface\\Icons\\INV_BannerPVP_02", 58)
    crest:SetPoint("TOPLEFT", 23, -19)

    local eyebrow = AddText(frame, "GUILD HUB · CLASSIC PROTOTYPE", GameFontNormalSmall, COLORS.gold)
    eyebrow:SetPoint("TOPLEFT", 96, -18)
    eyebrow:SetSize(360, 18)
    local guildName = AddText(frame, Data.guild.name, GameFontHighlightLarge, COLORS.paleGold)
    guildName:SetPoint("TOPLEFT", 96, -37)
    guildName:SetSize(465, 28)
    ui.guildName = guildName
    local playerLine = AddText(frame, "Добро пожаловать · визуальный прототип", GameFontNormalSmall, COLORS.cream)
    playerLine:SetPoint("TOPLEFT", 96, -65)
    playerLine:SetSize(470, 18)
    ui.playerLine = playerLine

    local onlineDot = frame:CreateTexture(nil, "ARTWORK")
    onlineDot:SetSize(8, 8)
    onlineDot:SetPoint("TOPRIGHT", -204, -32)
    onlineDot:SetColorTexture(unpack(COLORS.green))
    local online = AddText(frame, Data.guild.online .. " в сети", GameFontNormal, COLORS.green, "RIGHT")
    online:SetPoint("TOPRIGHT", -87, -25)
    online:SetSize(105, 22)
    local total = AddText(frame, Data.guild.total .. " участников", GameFontNormalSmall, COLORS.muted, "RIGHT")
    total:SetPoint("TOPRIGHT", -87, -49)
    total:SetSize(145, 20)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -12, -12)
    close:SetScript("OnClick", function()
        frame:Hide()
    end)

    local tabBar = CreateBackdropFrame("Frame", nil, frame)
    tabBar:SetPoint("TOPLEFT", 13, -91)
    tabBar:SetPoint("TOPRIGHT", -13, -91)
    tabBar:SetHeight(38)
    ApplyBackdrop(tabBar, { 0.055, 0.038, 0.022, 1 }, { 0.40, 0.29, 0.13, 1 })

    local tabNames = { "Обзор", "Участники", "Группы", "Задания", "Банк" }
    local tabWidth = 178
    for index, tabName in ipairs(tabNames) do
        local tab = CreateFrame("Button", nil, tabBar)
        tab:SetSize(tabWidth, 30)
        tab:SetPoint("LEFT", 4 + ((index - 1) * tabWidth), 0)

        local background = tab:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        tab.background = background
        local text = AddText(tab, tabName, GameFontNormal, COLORS.muted, "CENTER")
        text:SetAllPoints()
        tab.text = text
        local bottomLine = tab:CreateTexture(nil, "ARTWORK")
        bottomLine:SetPoint("BOTTOMLEFT", 7, 0)
        bottomLine:SetPoint("BOTTOMRIGHT", -7, 0)
        bottomLine:SetHeight(2)
        bottomLine:SetColorTexture(unpack(COLORS.gold))
        tab.bottomLine = bottomLine

        local highlight = tab:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(0.88, 0.63, 0.20, 0.09)
        tab:SetScript("OnClick", function()
            SelectTab(index)
        end)
        ui.tabs[index] = tab
    end

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", 20, -140)
    content:SetSize(900, 455)
    ui.content = content

    local builders = { BuildOverview, BuildMembers, BuildGroups, BuildTasks, BuildBank }
    for index, builder in ipairs(builders) do
        local panel = CreateFrame("Frame", nil, content)
        panel:SetAllPoints()
        builder(panel)
        ui.panels[index] = panel
    end

    local footerLine = frame:CreateTexture(nil, "ARTWORK")
    footerLine:SetPoint("BOTTOMLEFT", 20, 34)
    footerLine:SetPoint("BOTTOMRIGHT", -20, 34)
    footerLine:SetHeight(1)
    footerLine:SetColorTexture(0.55, 0.38, 0.14, 0.52)

    local footer = AddText(frame, "ТЕСТОВЫЕ ДАННЫЕ  ·  /ghp — открыть или скрыть  ·  окно можно перетаскивать", GameFontNormalSmall, COLORS.muted, "CENTER")
    footer:SetPoint("BOTTOMLEFT", 20, 12)
    footer:SetPoint("BOTTOMRIGHT", -20, 12)
    footer:SetHeight(17)

    local toast = CreateBackdropFrame("Frame", nil, frame)
    toast:SetSize(340, 36)
    toast:SetPoint("BOTTOM", frame, "BOTTOM", 0, 45)
    ApplyBackdrop(toast, { 0.08, 0.16, 0.07, 0.98 }, { 0.36, 0.69, 0.27, 1 })
    toast:SetFrameLevel(frame:GetFrameLevel() + 20)
    toast.text = AddText(toast, "", GameFontNormal, { 0.72, 1.0, 0.62 }, "CENTER")
    toast.text:SetAllPoints()
    toast:Hide()
    ui.toast = toast

    table.insert(UISpecialFrames, frame:GetName())
    SelectTab(1)
    frame:Hide()
end

function Addon:Toggle()
    if not ui.frame then
        BuildUI()
    end
    if ui.frame:IsShown() then
        ui.frame:Hide()
    else
        ui.frame:Show()
    end
end

Addon:RegisterEvent("ADDON_LOADED")
Addon:RegisterEvent("PLAYER_LOGIN")
Addon:SetScript("OnEvent", function(self, event, argument)
    if event == "ADDON_LOADED" and argument == ADDON_NAME then
        GuildHubClassicPrototypeDB = GuildHubClassicPrototypeDB or {}
        local firstRun = not GuildHubClassicPrototypeDB.hasLoaded
        GuildHubClassicPrototypeDB.hasLoaded = true
        BuildUI()
        if firstRun then
            C_Timer.After(1.0, function()
                if ui.frame then
                    ui.frame:Show()
                    print("|cffe6b84cGuild Hub Classic:|r прототип открыт. Команда: /ghp")
                end
            end)
        end
    elseif event == "PLAYER_LOGIN" then
        UpdateGuildHeader()
    end
end)

SLASH_GUILDHUBCLASSICPROTOTYPE1 = "/ghp"
SLASH_GUILDHUBCLASSICPROTOTYPE2 = "/guildhub"
SlashCmdList.GUILDHUBCLASSICPROTOTYPE = function(message)
    message = string.lower((message or ""):match("^%s*(.-)%s*$"))
    if message == "reset" then
        ResetPosition()
        if ui.frame then
            ui.frame:Show()
        end
        return
    end
    Addon:Toggle()
end
