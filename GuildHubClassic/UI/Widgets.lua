local _, ns = ...

local Widgets = {}
ns.ui.Widgets = Widgets

Widgets.colors = {
    gold = { 0.90, 0.72, 0.30 },
    pale = { 1.00, 0.88, 0.54 },
    cream = { 0.93, 0.86, 0.70 },
    muted = { 0.65, 0.60, 0.50 },
    green = { 0.32, 0.78, 0.38 },
    blue = { 0.35, 0.68, 0.95 },
    red = { 0.90, 0.28, 0.22 },
    panel = { 0.075, 0.055, 0.035, 0.98 },
    border = { 0.55, 0.39, 0.16, 1.0 },
}

function Widgets:Frame(frameType, name, parent)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    return CreateFrame(frameType or "Frame", name, parent, template)
end

function Widgets:Backdrop(frame, background, border)
    if not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 24, edgeSize = 13,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(unpack(background or self.colors.panel))
    frame:SetBackdropBorderColor(unpack(border or self.colors.border))
end

function Widgets:Label(parent, text, font, color, justify)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(font or GameFontNormal)
    label:SetText(text or "")
    label:SetTextColor(unpack(color or self.colors.cream))
    label:SetJustifyH(justify or "LEFT")
    label:SetJustifyV("TOP")
    return label
end

function Widgets:Button(parent, text, width, callback)
    local button = self:Frame("Button", nil, parent)
    button:SetSize(width or 120, 28)
    self:Backdrop(button, { 0.19, 0.11, 0.045, 1 }, { 0.72, 0.51, 0.19, 1 })
    button.label = self:Label(button, text, GameFontNormal, self.colors.pale, "CENTER")
    button.label:SetAllPoints()
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(0.90, 0.66, 0.20, 0.13)
    button:SetScript("OnClick", callback or function() end)
    return button
end

function Widgets:EditBox(parent, width)
    local box = self:Frame("EditBox", nil, parent)
    box:SetSize(width or 300, 28)
    self:Backdrop(box, { 0.025, 0.02, 0.012, 1 }, { 0.42, 0.31, 0.14, 1 })
    box:SetFontObject(ChatFontNormal)
    box:SetTextInsets(8, 8, 0, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(500)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    box:SetScript("OnEnterPressed", box.ClearFocus)
    return box
end

function Widgets:Card(parent, y, height, title, subtitle, body)
    local card = self:Frame("Frame", nil, parent)
    card:SetPoint("TOPLEFT", 2, -y)
    card:SetPoint("TOPRIGHT", -2, -y)
    card:SetHeight(height)
    self:Backdrop(card, self.colors.panel, self.colors.border)
    local titleLabel = self:Label(card, title, GameFontNormalLarge, self.colors.pale)
    titleLabel:SetPoint("TOPLEFT", 14, -12)
    titleLabel:SetPoint("TOPRIGHT", -160, -12)
    titleLabel:SetHeight(22)
    local subLabel = self:Label(card, subtitle, GameFontNormalSmall, self.colors.muted, "RIGHT")
    subLabel:SetPoint("TOPRIGHT", -14, -14)
    subLabel:SetSize(145, 18)
    local bodyLabel = self:Label(card, body, GameFontNormal, self.colors.cream)
    bodyLabel:SetPoint("TOPLEFT", 14, -40)
    bodyLabel:SetPoint("BOTTOMRIGHT", -14, 10)
    bodyLabel:SetWordWrap(true)
    card.titleLabel = titleLabel
    card.bodyLabel = bodyLabel
    return card
end

function Widgets:ShowForm(title, fields, onSave)
    if self.modal then
        self.modal:Hide()
    end
    local parent = ns.ui.MainFrame and ns.ui.MainFrame.frame or UIParent
    local modal = self:Frame("Frame", nil, parent)
    modal:SetFrameStrata("FULLSCREEN_DIALOG")
    modal:SetSize(520, 128 + (#fields * 48))
    modal:SetPoint("CENTER")
    self:Backdrop(modal, { 0.035, 0.025, 0.015, 1 }, { 0.80, 0.58, 0.22, 1 })
    self.modal = modal

    local heading = self:Label(modal, title, GameFontHighlightLarge, self.colors.pale)
    heading:SetPoint("TOPLEFT", 18, -16)
    heading:SetPoint("TOPRIGHT", -18, -16)
    heading:SetHeight(24)
    local inputs = {}
    for index, field in ipairs(fields) do
        local y = 50 + ((index - 1) * 48)
        local label = self:Label(modal, field.label, GameFontNormalSmall, self.colors.gold)
        label:SetPoint("TOPLEFT", 20, -y)
        label:SetSize(150, 20)
        local input = self:EditBox(modal, 320)
        input:SetPoint("TOPRIGHT", -20, -y + 4)
        input:SetText(tostring(field.default or ""))
        inputs[field.key] = input
    end
    local cancel = self:Button(modal, ns:L("CANCEL"), 110, function() modal:Hide() end)
    cancel:SetPoint("BOTTOMRIGHT", -18, 16)
    local save = self:Button(modal, ns:L("SAVE"), 110, function()
        local values = {}
        for key, input in pairs(inputs) do values[key] = input:GetText() end
        local ok, errorMessage = onSave(values)
        if ok ~= false and ok ~= nil then
            modal:Hide()
            if ns.ui.MainFrame then ns.ui.MainFrame:Refresh() end
        elseif errorMessage then
            ns:Print(errorMessage)
        end
    end)
    save:SetPoint("RIGHT", cancel, "LEFT", -10, 0)
    modal:Show()
    return modal
end

