local _, ns = ...

local MainFrame = {
    selectedTab = "overview",
    bankSort = "name",
    bankFilterTag = nil,
}
ns.ui.MainFrame = MainFrame

local W = ns.ui.Widgets
local C = W.colors

local tabs = {
    { id = "overview", label = "TAB_OVERVIEW" },
    { id = "members", label = "TAB_MEMBERS" },
    { id = "groups", label = "TAB_GROUPS" },
    { id = "tasks", label = "TAB_TASKS" },
    { id = "requests", label = "TAB_REQUESTS" },
    { id = "bank", label = "TAB_BANK" },
}

local function formatTime(timestamp)
    if not timestamp then return "—" end
    return date("%d.%m %H:%M", timestamp)
end

local function shortName(name)
    return tostring(name or ""):match("^[^-]+") or tostring(name or "")
end

local function localizedError(code)
    local guild = ns.Database:GetGuild()
    if code == "permission" then return ns:L("ERROR_NOT_OFFICER") end
    if code == "level" then return ns:L("ERROR_LEVEL", guild.config.requestMinLevel or 6) end
    if code == "request-limit" then
        return ns:L("ERROR_REQUEST_LIMIT", guild.config.maxActiveRequests or 5)
    end
    if code == "group-limit" then
        return ns:L("ERROR_GROUP_LIMIT", guild.config.maxActiveGroups or 3)
    end
    if code == "not-keeper" then return ns:L("BANK_NOT_KEEPER") end
    if code == "bank-not-open" then return ns:L("BANK_OPEN_REQUIRED") end
    if code == "invalid" or tostring(code):find("invalid", 1, true) then return ns:L("ERROR_INVALID") end
    return tostring(code or ns:L("ERROR_INVALID"))
end

local function formResult(entity, errorCode)
    if not entity then
        return false, localizedError(errorCode)
    end
    ns:Print(ns:L("SAVED"))
    return true
end

local function parseStart(value)
    value = ns.Validation:Clean(value, 40)
    if value == "" or value:lower() == "now" or value:lower() == "сейчас"
        or value:lower() == "зараз" then
        return ns.GameAPI:Now()
    end
    local minutes = tonumber(value)
    if minutes then
        return ns.GameAPI:Now() + math.max(0, minutes) * 60
    end
    local day, month, year, hour, minute = value:match("^(%d%d?)%.(%d%d?)%.(%d%d%d%d)%s+(%d%d?):(%d%d)$")
    if day then
        return time({ year = tonumber(year), month = tonumber(month), day = tonumber(day),
            hour = tonumber(hour), min = tonumber(minute) })
    end
    return nil
end

function MainFrame:Initialize()
    if self.frame then return end
    local frame = W:Frame("Frame", "GuildHubClassicFrame", UIParent)
    frame:SetSize(940, 640)
    frame:SetPoint("CENTER", UIParent, "CENTER", ns.Database.char.window.x or 0,
        ns.Database.char.window.y or 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(current)
        current:StopMovingOrSizing()
        local x, y = current:GetCenter()
        local px, py = UIParent:GetCenter()
        if x and y and px and py then
            ns.Database.char.window.x = x - px
            ns.Database.char.window.y = y - py
        end
    end)
    frame:SetScript("OnShow", function() MainFrame:Refresh() end)
    W:Backdrop(frame, { 0.035, 0.025, 0.015, 0.99 }, { 0.76, 0.55, 0.22, 1 })
    self.frame = frame

    local header = frame:CreateTexture(nil, "BACKGROUND")
    header:SetPoint("TOPLEFT", 8, -8)
    header:SetPoint("TOPRIGHT", -8, -8)
    header:SetHeight(76)
    header:SetTexture("Interface\\QuestFrame\\QuestBG")
    header:SetTexCoord(0.04, 0.96, 0.07, 0.29)
    header:SetVertexColor(0.42, 0.27, 0.11, 0.82)

    self.title = W:Label(frame, ns:L("TITLE"), GameFontHighlightLarge, C.pale)
    self.title:SetPoint("TOPLEFT", 24, -20)
    self.title:SetSize(520, 28)
    self.subtitle = W:Label(frame, ns:L("SUBTITLE"), GameFontNormalSmall, C.cream)
    self.subtitle:SetPoint("TOPLEFT", 24, -53)
    self.subtitle:SetSize(600, 20)
    self.guildStats = W:Label(frame, "", GameFontNormal, C.green, "RIGHT")
    self.guildStats:SetPoint("TOPRIGHT", -54, -30)
    self.guildStats:SetSize(260, 24)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -8, -8)

    local settings = W:Button(frame, "⚙", 32, function() MainFrame:ShowSettings() end)
    settings:SetPoint("TOPRIGHT", -47, -48)
    settings:SetSize(32, 24)

    local tabBar = W:Frame("Frame", nil, frame)
    tabBar:SetPoint("TOPLEFT", 12, -90)
    tabBar:SetPoint("TOPRIGHT", -12, -90)
    tabBar:SetHeight(36)
    W:Backdrop(tabBar, { 0.055, 0.038, 0.022, 1 }, { 0.40, 0.29, 0.13, 1 })
    self.tabButtons = {}
    for index, tab in ipairs(tabs) do
        local button = CreateFrame("Button", nil, tabBar)
        button:SetSize(148, 28)
        button:SetPoint("LEFT", 4 + ((index - 1) * 148), 0)
        button.background = button:CreateTexture(nil, "BACKGROUND")
        button.background:SetAllPoints()
        button.label = W:Label(button, ns:L(tab.label), GameFontNormal, C.muted, "CENTER")
        button.label:SetAllPoints()
        button:SetScript("OnClick", function()
            MainFrame.selectedTab = tab.id
            MainFrame:Refresh()
        end)
        self.tabButtons[tab.id] = button
    end

    local actionBar = CreateFrame("Frame", nil, frame)
    actionBar:SetPoint("TOPLEFT", 18, -135)
    actionBar:SetPoint("TOPRIGHT", -18, -135)
    actionBar:SetHeight(34)
    self.actionBar = actionBar
    self.search = W:EditBox(actionBar, 220)
    self.search:SetPoint("LEFT", 0, 0)
    self.search:SetText("")
    self.search:SetScript("OnEnterPressed", function(box)
        box:ClearFocus()
        MainFrame:Refresh()
    end)
    self.primaryAction = W:Button(actionBar, ns:L("CREATE"), 145)
    self.primaryAction:SetPoint("RIGHT", 0, 0)
    self.secondaryAction = W:Button(actionBar, ns:L("REFRESH"), 145)
    self.secondaryAction:SetPoint("RIGHT", self.primaryAction, "LEFT", -8, 0)
    self.thirdAction = W:Button(actionBar, ns:L("SYNC"), 145)
    self.thirdAction:SetPoint("RIGHT", self.secondaryAction, "LEFT", -8, 0)

    local scroll = CreateFrame("ScrollFrame", "GuildHubClassicScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -176)
    scroll:SetPoint("BOTTOMRIGHT", -40, 42)
    self.scroll = scroll

    self.footer = W:Label(frame, "", GameFontNormalSmall, C.muted, "CENTER")
    self.footer:SetPoint("BOTTOMLEFT", 20, 14)
    self.footer:SetPoint("BOTTOMRIGHT", -20, 14)
    self.footer:SetHeight(18)
    table.insert(UISpecialFrames, frame:GetName())
    frame:Hide()
end

function MainFrame:SetActions(primaryText, primaryCallback, secondaryText, secondaryCallback,
    thirdText, thirdCallback)
    local entries = {
        { self.primaryAction, primaryText, primaryCallback },
        { self.secondaryAction, secondaryText, secondaryCallback },
        { self.thirdAction, thirdText, thirdCallback },
    }
    for _, entry in ipairs(entries) do
        if entry[2] then
            entry[1].label:SetText(entry[2])
            entry[1]:SetScript("OnClick", entry[3] or function() end)
            entry[1]:Show()
        else
            entry[1]:Hide()
        end
    end
end

function MainFrame:NewContent()
    if self.content then self.content:Hide() end
    local child = CreateFrame("Frame", nil, self.scroll)
    child:SetWidth(878)
    child:SetHeight(1)
    self.scroll:SetScrollChild(child)
    self.content = child
    return child
end

function MainFrame:FinishContent(height)
    self.content:SetHeight(math.max(420, height + 8))
end

function MainFrame:Refresh()
    if not self.frame then return end
    ns.Store:RunMaintenance()
    local guildName = ns.Database.db.settings.demoMode and "Demo Guild"
        or ns.GameAPI:GetGuildName() or ns:L("TITLE")
    local online, total = ns.modules.Roster:GetStats()
    self.title:SetText(guildName)
    self.subtitle:SetText(ns:L("SUBTITLE"))
    self.guildStats:SetText(ns:L("ONLINE", online) .. " · " .. ns:L("MEMBERS_TOTAL", total))
    for id, button in pairs(self.tabButtons) do
        local selected = id == self.selectedTab
        button.background:SetColorTexture(selected and 0.34 or 0.10,
            selected and 0.20 or 0.065, selected and 0.07 or 0.035, 0.98)
        button.label:SetTextColor(unpack(selected and C.pale or C.muted))
    end
    local renderer = self["Render" .. self.selectedTab:sub(1, 1):upper()
        .. self.selectedTab:sub(2)]
    if renderer then renderer(self) end
    local demo = ns.Database.db.settings.demoMode and " · " .. ns:L("DEMO_WARNING") or ""
    self.footer:SetText("Guild Hub Classic " .. ns.version .. " · Classic Era" .. demo)
end

function MainFrame:Toggle()
    self:Initialize()
    self.frame:SetShown(not self.frame:IsShown())
end

function MainFrame:ResetPosition()
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER")
    ns.Database.char.window.x, ns.Database.char.window.y = 0, 0
end

function MainFrame:RenderOverview()
    self.search:Hide()
    self:SetActions(ns.Permissions:IsOfficer() and ns:L("ADD_NEWS") or nil,
        function() MainFrame:ShowNewsForm() end,
        ns:L("SYNC"), function()
            if ns.Comm:RequestSync() then ns:Print(ns:L("SYNC_REQUESTED")) end
        end)
    local child, y = self:NewContent(), 0
    local respect = ns.modules.Tasks:GetRespect()
    local peers = ns.Comm:GetCompatiblePeerCount()
    local requestCount = #ns.modules.Requests:List(false)
    local groupCount = #ns.modules.Groups:List(false)
    local summary = W:Card(child, y, 90, ns:L("MY_RESPECT"), tostring(respect),
        ns:L("SYNC_STATUS") .. ": " .. (peers > 0 and ns:L("SYNC_OK") or ns:L("SYNC_WAITING"))
        .. " · " .. ns:L("PEERS", peers) .. "\n"
        .. ns:L("OPEN_REQUESTS") .. ": " .. requestCount .. " · "
        .. ns:L("UPCOMING_GROUPS") .. ": " .. groupCount)
    y = y + 100
    for _, item in ipairs(ns.modules.News:List()) do
        local card = W:Card(child, y, 92, item.title, shortName(item.owner), item.description)
        if item.owner == ns.GameAPI:GetPlayerName() or ns.Permissions:IsOfficer() then
            local close = W:Button(card, ns:L("ARCHIVE"), 95, function()
                MainFrame:ShowCloseForm("news", item.id)
            end)
            close:SetPoint("BOTTOMRIGHT", -12, 10)
            card.bodyLabel:SetPoint("BOTTOMRIGHT", -115, 10)
        end
        y = y + 102
    end
    if #ns.modules.News:List() == 0 then
        W:Card(child, y, 70, ns:L("NEWS"), "", ns:L("EMPTY"))
        y = y + 80
    end
    self:FinishContent(y)
end

function MainFrame:RenderMembers()
    self.search:Show()
    self:SetActions(ns:L("PROFILE"), function() MainFrame:ShowProfileForm() end,
        ns:L("REFRESH"), function() ns.modules.Roster:Refresh() MainFrame:Refresh() end)
    local child, y = self:NewContent(), 0
    local query = self.search:GetText():lower()
    local player = ns.GameAPI:GetPlayerName()
    for _, member in ipairs(ns.modules.Roster:List(false)) do
        if query == "" or member.name:lower():find(query, 1, true) then
            local profile = ns.modules.Profiles:Get(member.name)
            local status = profile and (profile.roles .. " · " .. profile.professions) or ns:L("EMPTY")
            local card = W:Card(child, y, 70, shortName(member.name),
                tostring(member.level) .. " · " .. member.className,
                member.rankName .. " · " .. member.zone .. " · " .. status)
            local dot = card:CreateTexture(nil, "ARTWORK")
            dot:SetSize(7, 7)
            dot:SetPoint("TOPLEFT", 5, -20)
            dot:SetColorTexture(unpack(member.online and C.green or C.muted))
            if profile and profile.mainCharacter == player and not profile.mainConfirmed then
                local confirm = W:Button(card, ns:L("CONFIRM"), 100, function()
                    ns.modules.Profiles:ConfirmAlt(profile.id)
                    MainFrame:Refresh()
                end)
                confirm:SetPoint("BOTTOMRIGHT", -12, 8)
                card.bodyLabel:SetPoint("BOTTOMRIGHT", -122, 8)
            end
            y = y + 80
        end
    end
    self:FinishContent(y)
end


function MainFrame:RenderRequests()
    self.search:Show()
    self:SetActions(ns:L("ADD_REQUEST"), function() MainFrame:ShowRequestForm() end)
    local child, y = self:NewContent(), 0
    local player = ns.GameAPI:GetPlayerName()
    local query = self.search:GetText():lower()
    for _, request in ipairs(ns.modules.Requests:List(false)) do
        if query == "" or request.title:lower():find(query, 1, true)
            or request.description:lower():find(query, 1, true) then
            local card = W:Card(child, y, 105, request.title,
                shortName(request.owner) .. " · " .. formatTime(request.expiresAt), request.description)
            card.bodyLabel:SetPoint("BOTTOMRIGHT", -250, 12)
            local action
            if request.owner == player or ns.Permissions:IsOfficer() then
                action = W:Button(card, ns:L("COMPLETE"), 105, function()
                    MainFrame:ShowCloseForm("requests", request.id)
                end)
            else
                action = W:Button(card, ns:L("RESPOND"), 105, function()
                    MainFrame:ShowResponseForm(request)
                end)
            end
            action:SetPoint("BOTTOMRIGHT", -12, 12)
            y = y + 115
            if request.owner == player then
                for _, response in ipairs(ns.Store:List("responses", false)) do
                    if response.requestId == request.id then
                        local responseCard = W:Card(child, y, 70, shortName(response.owner),
                            response.status, response.message)
                        if response.status == "pending" then
                            local accept = W:Button(responseCard, ns:L("ACCEPT"), 90, function()
                                ns.modules.Requests:SetResponseStatus(response.id, "accepted") MainFrame:Refresh()
                            end)
                            accept:SetPoint("BOTTOMRIGHT", -108, 10)
                            local decline = W:Button(responseCard, ns:L("DECLINE"), 90, function()
                                ns.modules.Requests:SetResponseStatus(response.id, "declined") MainFrame:Refresh()
                            end)
                            decline:SetPoint("BOTTOMRIGHT", -12, 10)
                        end
                        y = y + 80
                    end
                end
            end
        end
    end
    self:FinishContent(y)
end

function MainFrame:RenderGroups()
    self.search:Show()
    self:SetActions(ns:L("ADD_GROUP"), function() MainFrame:ShowGroupForm() end)
    local child, y = self:NewContent(), 0
    local player = ns.GameAPI:GetPlayerName()
    local query = self.search:GetText():lower()
    for _, group in ipairs(ns.modules.Groups:List(false)) do
        if query == "" or group.title:lower():find(query, 1, true) then
            local body = group.description .. "\n" .. ns:L("ROLES") .. ": " .. (group.roles or "—")
            local card = W:Card(child, y, 112, group.title,
                shortName(group.owner) .. " · " .. formatTime(group.startAt), body)
            card.bodyLabel:SetPoint("BOTTOMRIGHT", -250, 12)
            local action
            if group.owner == player or ns.Permissions:IsOfficer() then
                action = W:Button(card, ns:L("COMPLETE"), 105, function()
                    MainFrame:ShowCloseForm("groups", group.id)
                end)
            else
                action = W:Button(card, ns:L("RESPOND"), 105, function()
                    MainFrame:ShowApplicationForm(group)
                end)
            end
            action:SetPoint("BOTTOMRIGHT", -12, 12)
            y = y + 122
            if group.owner == player then
                for _, application in ipairs(ns.Store:List("applications", false)) do
                    if application.groupId == group.id then
                        local appCard = W:Card(child, y, 72, shortName(application.owner),
                            application.status, application.role .. " · " .. application.comment)
                        if application.status == "pending" then
                            local accept = W:Button(appCard, ns:L("ACCEPT"), 90, function()
                                ns.modules.Groups:SetApplicationStatus(application.id, "accepted") MainFrame:Refresh()
                            end)
                            accept:SetPoint("BOTTOMRIGHT", -108, 10)
                            local decline = W:Button(appCard, ns:L("DECLINE"), 90, function()
                                ns.modules.Groups:SetApplicationStatus(application.id, "declined") MainFrame:Refresh()
                            end)
                            decline:SetPoint("BOTTOMRIGHT", -12, 10)
                        elseif application.status == "accepted" then
                            local invite = W:Button(appCard, ns:L("INVITE"), 100, function()
                                ns.modules.Groups:Invite(application.id)
                            end)
                            invite:SetPoint("BOTTOMRIGHT", -12, 10)
                        end
                        y = y + 82
                    end
                end
            end
        end
    end
    self:FinishContent(y)
end

function MainFrame:RenderTasks()
    self.search:Show()
    self:SetActions(ns.Permissions:IsOfficer() and ns:L("ADD_TASK") or nil,
        function() MainFrame:ShowTaskForm() end)
    local child, y = self:NewContent(), 0
    local query = self.search:GetText():lower()
    for _, task in ipairs(ns.modules.Tasks:List(false)) do
        if query == "" or task.title:lower():find(query, 1, true) then
            local reported, confirmed = ns.modules.Tasks:GetProgress(task.id)
            local progress = ns:L("REPORTED_PROGRESS") .. ": " .. tostring(reported)
                .. " · " .. ns:L("CONFIRMED_PROGRESS") .. ": " .. tostring(confirmed)
                .. " / " .. tostring(task.goal)
            local card = W:Card(child, y, 105, task.title,
                tostring(task.respect or 0) .. " Respect", task.description .. "\n" .. progress)
            card.bodyLabel:SetPoint("BOTTOMRIGHT", -250, 12)
            local report = W:Button(card, ns:L("REPORT_CONTRIBUTION"), 170, function()
                MainFrame:ShowContributionForm(task)
            end)
            report:SetPoint("BOTTOMRIGHT", -12, 12)
            if ns.Permissions:IsOfficer() then
                local complete = W:Button(card, ns:L("COMPLETE"), 105, function()
                    MainFrame:ShowCloseForm("tasks", task.id)
                end)
                complete:SetPoint("RIGHT", report, "LEFT", -8, 0)
            end
            y = y + 115
            if ns.Permissions:IsOfficer() then
                for _, contribution in ipairs(ns.Store:List("contributions", false)) do
                    if contribution.taskId == task.id and contribution.status == "pending" then
                        local contributionCard = W:Card(child, y, 72, shortName(contribution.owner),
                            tostring(contribution.amount), contribution.comment)
                        local confirm = W:Button(contributionCard, ns:L("CONFIRM"), 100, function()
                            ns.modules.Tasks:Confirm(contribution.id, true) MainFrame:Refresh()
                        end)
                        confirm:SetPoint("BOTTOMRIGHT", -118, 10)
                        local reject = W:Button(contributionCard, ns:L("REJECT"), 100, function()
                            ns.modules.Tasks:Confirm(contribution.id, false) MainFrame:Refresh()
                        end)
                        reject:SetPoint("BOTTOMRIGHT", -12, 10)
                        y = y + 82
                    end
                end
            end
        end
    end
    self:FinishContent(y)
end

function MainFrame:RenderBank()
    self.search:Show()
    self:SetActions(ns:L("SCAN_BANK"), function()
        local snapshot, errorCode = ns.modules.Bank:Scan()
        if snapshot then
            ns:Print(ns:L("BANK_SCANNED", snapshot.itemTypeCount or 0)) MainFrame:Refresh()
        else ns:Print(localizedError(errorCode)) end
    end, ns.Permissions:IsOfficer() and ns:L("BANK_KEEPER") or nil,
        function() MainFrame:ShowKeeperForm() end,
        ns.Permissions:IsOfficer() and ns:L("SMART_VIEWS") or nil,
        function() MainFrame:ShowViewForm() end)
    local child, y = self:NewContent(), 0
    local query = self.search:GetText():lower()
    local control = W:Card(child, y, 66, ns:L("SMART_VIEWS"),
        self.bankFilterTag or ns:L("ALL"), ns:L("SORT") .. ": " .. self.bankSort)
    local sort = W:Button(control, ns:L("SORT"), 90, function()
        local order = { "name", "count", "owner", "updated" }
        local index = 1
        for i, value in ipairs(order) do if value == MainFrame.bankSort then index = i end end
        MainFrame.bankSort = order[(index % #order) + 1]
        MainFrame:Refresh()
    end)
    sort:SetPoint("BOTTOMRIGHT", -12, 8)
    local clear = W:Button(control, ns:L("ALL"), 70, function()
        MainFrame.bankFilterTag = nil
        MainFrame:Refresh()
    end)
    clear:SetPoint("RIGHT", sort, "LEFT", -8, 0)
    y = y + 76

    for _, view in ipairs(ns.Store:List("bankViews", false)) do
        local viewCard = W:Card(child, y, 58, view.name, "", view.filters and view.filters.tag or "")
        local selectView = W:Button(viewCard, ns:L("ACCEPT"), 90, function()
            MainFrame.bankFilterTag = view.filters and view.filters.tag or nil
            MainFrame:Refresh()
        end)
        selectView:SetPoint("BOTTOMRIGHT", -12, 8)
        y = y + 68
    end

    local player = ns.GameAPI:GetPlayerName()
    for _, bankRequest in ipairs(ns.Store:List("bankRequests", false)) do
        if bankRequest.keeper == player or ns.Permissions:IsOfficer() then
            local requestCard = W:Card(child, y, 76, bankRequest.itemName,
                tostring(bankRequest.count) .. " · " .. shortName(bankRequest.owner), ns:L("BANK_REQUESTS"))
            if bankRequest.status == "pending" then
                local accept = W:Button(requestCard, ns:L("ACCEPT"), 90, function()
                    ns.modules.Bank:SetRequestStatus(bankRequest.id, "accepted")
                    MainFrame:Refresh()
                end)
                accept:SetPoint("BOTTOMRIGHT", -108, 8)
                local decline = W:Button(requestCard, ns:L("DECLINE"), 90, function()
                    ns.modules.Bank:SetRequestStatus(bankRequest.id, "declined")
                    MainFrame:Refresh()
                end)
                decline:SetPoint("BOTTOMRIGHT", -12, 8)
            elseif bankRequest.status == "accepted" then
                local complete = W:Button(requestCard, ns:L("COMPLETE"), 100, function()
                    ns.modules.Bank:SetRequestStatus(bankRequest.id, "fulfilled")
                    MainFrame:Refresh()
                end)
                complete:SetPoint("BOTTOMRIGHT", -12, 8)
            end
            y = y + 86
        end
    end

    local items = ns.modules.Bank:ListItems(self.bankFilterTag and { tag = self.bankFilterTag } or nil)
    table.sort(items, function(a, b)
        if self.bankSort == "count" then return (a.count or 0) > (b.count or 0) end
        if self.bankSort == "owner" then return (a.owner or "") < (b.owner or "") end
        if self.bankSort == "updated" then return (a.scannedAt or 0) > (b.scannedAt or 0) end
        return (a.name or "") < (b.name or "")
    end)
    for _, item in ipairs(items) do
        if query == "" or (item.name or ""):lower():find(query, 1, true) then
            local tagText = #item.tags > 0 and table.concat(item.tags, ", ") or ns:L("UNTYPED")
            local card = W:Card(child, y, 82, item.name,
                tostring(item.count) .. " · " .. shortName(item.owner), tagText .. " · " .. item.comment)
            local request = W:Button(card, ns:L("REQUEST_ITEM"), 130, function()
                MainFrame:ShowBankRequestForm(item)
            end)
            request:SetPoint("BOTTOMRIGHT", -12, 10)
            if ns.Permissions:IsOfficer() then
                local tags = W:Button(card, ns:L("TAGS"), 90, function()
                    MainFrame:ShowTagsForm(item)
                end)
                tags:SetPoint("RIGHT", request, "LEFT", -8, 0)
            end
            y = y + 92
        end
    end
    self:FinishContent(y)
end

function MainFrame:ShowNewsForm()
    W:ShowForm(ns:L("ADD_NEWS"), {
        { key = "title", label = ns:L("TITLE_FIELD") },
        { key = "description", label = ns:L("DESCRIPTION") },
    }, function(values) return formResult(ns.modules.News:Create(values.title, values.description)) end)
end

function MainFrame:ShowCloseForm(kind, id)
    W:ShowForm(ns:L("COMPLETE"), {
        { key = "reason", label = ns:L("CLOSE_REASON") },
    }, function(values)
        return formResult(ns.Store:Close(kind, id, values.reason))
    end)
end

function MainFrame:ShowProfileForm()
    local profile = ns.modules.Profiles:Get() or {}
    W:ShowForm(ns:L("PROFILE"), {
        { key = "roles", label = ns:L("ROLES"), default = profile.roles },
        { key = "professions", label = ns:L("PROFESSIONS"), default = profile.professions },
        { key = "mainCharacter", label = ns:L("MAIN_CHARACTER"), default = profile.mainCharacter },
        { key = "comment", label = ns:L("COMMENT"), default = profile.comment },
        { key = "readyToHelp", label = ns:L("READY_TO_HELP") .. " (1/0)", default = profile.readyToHelp and "1" or "0" },
    }, function(values)
        values.readyToHelp = values.readyToHelp == "1"
        return formResult(ns.modules.Profiles:Save(values))
    end)
end

function MainFrame:ShowRequestForm()
    W:ShowForm(ns:L("ADD_REQUEST"), {
        { key = "title", label = ns:L("TITLE_FIELD") },
        { key = "description", label = ns:L("DESCRIPTION") },
        { key = "category", label = ns:L("CATEGORY") .. " (help/materials/question)", default = "help" },
        { key = "durationHours", label = ns:L("EXPIRES") .. " (1/6/12/24/72/168)", default = "24" },
    }, function(values) return formResult(ns.modules.Requests:Create(values)) end)
end

function MainFrame:ShowResponseForm(request)
    W:ShowForm(ns:L("RESPOND") .. ": " .. request.title, {
        { key = "message", label = ns:L("COMMENT") },
    }, function(values) return formResult(ns.modules.Requests:Respond(request.id, values.message)) end)
end

function MainFrame:ShowGroupForm()
    W:ShowForm(ns:L("ADD_GROUP"), {
        { key = "title", label = ns:L("TITLE_FIELD") },
        { key = "description", label = ns:L("DESCRIPTION") },
        { key = "size", label = ns:L("GROUP_SIZE") .. " (2-40)", default = "5" },
        { key = "roles", label = ns:L("ROLES") },
        { key = "minLevel", label = ns:L("LEVEL_RANGE") .. " min", default = "1" },
        { key = "maxLevel", label = ns:L("LEVEL_RANGE") .. " max", default = "60" },
        { key = "start", label = ns:L("START_TIME") .. " (now/min/DD.MM.YYYY HH:MM)", default = "now" },
    }, function(values)
        values.startAt = parseStart(values.start)
        return formResult(ns.modules.Groups:Create(values))
    end)
end

function MainFrame:ShowApplicationForm(group)
    W:ShowForm(ns:L("RESPOND") .. ": " .. group.title, {
        { key = "role", label = ns:L("ROLES") },
        { key = "comment", label = ns:L("COMMENT") },
    }, function(values) return formResult(ns.modules.Groups:Apply(group.id, values.role, values.comment)) end)
end

function MainFrame:ShowTaskForm()
    W:ShowForm(ns:L("ADD_TASK"), {
        { key = "title", label = ns:L("TITLE_FIELD") },
        { key = "description", label = ns:L("DESCRIPTION") },
        { key = "goal", label = ns:L("GOAL") },
        { key = "respect", label = ns:L("RESPECT"), default = "0" },
    }, function(values) return formResult(ns.modules.Tasks:Create(values)) end)
end

function MainFrame:ShowContributionForm(task)
    W:ShowForm(ns:L("REPORT_CONTRIBUTION") .. ": " .. task.title, {
        { key = "amount", label = ns:L("COUNT") },
        { key = "comment", label = ns:L("COMMENT") },
    }, function(values) return formResult(ns.modules.Tasks:Report(task.id, values)) end)
end

function MainFrame:ShowKeeperForm()
    W:ShowForm(ns:L("BANK_KEEPER"), {
        { key = "name", label = ns:L("NAME") .. "-Realm" },
        { key = "enabled", label = ns:L("ACTIVE") .. " (1/0)", default = "1" },
    }, function(values)
        local ok, errorCode = ns.modules.Bank:SetKeeper(values.name, values.enabled == "1")
        if not ok then return false, localizedError(errorCode) end
        return true
    end)
end

function MainFrame:ShowBankRequestForm(item)
    W:ShowForm(ns:L("REQUEST_ITEM") .. ": " .. item.name, {
        { key = "count", label = ns:L("COUNT"), default = "1" },
    }, function(values) return formResult(ns.modules.Bank:RequestItem(item, values.count)) end)
end

function MainFrame:ShowTagsForm(item)
    W:ShowForm(ns:L("TAGS") .. ": " .. item.name, {
        { key = "tags", label = ns:L("TAGS") .. " (comma separated)", default = table.concat(item.tags, ", ") },
        { key = "comment", label = ns:L("COMMENT"), default = item.comment },
    }, function(values)
        local tags = {}
        for tag in values.tags:gmatch("[^,]+") do
            tag = ns.Validation:Clean(tag, 40)
            if tag ~= "" then tags[#tags + 1] = tag end
        end
        return formResult(ns.modules.Bank:SetTags(item.itemID, tags, values.comment))
    end)
end

function MainFrame:ShowViewForm()
    W:ShowForm(ns:L("SMART_VIEWS"), {
        { key = "name", label = ns:L("NAME") },
        { key = "tag", label = ns:L("TAGS") },
    }, function(values)
        return formResult(ns.modules.Bank:CreateView(values.name, {
            tag = ns.Validation:Clean(values.tag, 40),
        }))
    end)
end

function MainFrame:ShowSettings()
    local guild = ns.Database:GetGuild()
    W:ShowForm(ns:L("SETTINGS"), {
        { key = "locale", label = ns:L("LANGUAGE") .. " (ruRU/enUS/ukUA)", default = ns:GetLocaleCode() },
        { key = "officerRank", label = ns:L("OFFICER_RANK"), default = guild.config.officerRankThreshold },
        { key = "notifications", label = ns:L("IMPORTANT_NOTIFICATIONS") .. " (1/0)",
            default = ns.Database.db.settings.importantNotifications and "1" or "0" },
    }, function(values)
        if values.locale == "ruRU" or values.locale == "enUS" or values.locale == "ukUA" then
            ns.Database.db.settings.locale = values.locale
        end
        local rank = tonumber(values.officerRank)
        ns.Database.db.settings.importantNotifications = values.notifications == "1"
        if rank and ns.Permissions:CanChangeConfig() then
            guild.config.officerRankThreshold = math.max(0, math.floor(rank))
            ns.Comm:BroadcastConfig("officerRankThreshold", guild.config.officerRankThreshold)
        end
        MainFrame:Refresh()
        return true
    end)
end
