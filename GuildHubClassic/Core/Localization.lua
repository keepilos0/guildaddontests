local _, ns = ...

local supported = { enUS = true, ruRU = true, ukUA = true }

function ns:GetLocaleCode()
    local configured = GuildHubClassicDB and GuildHubClassicDB.settings
        and GuildHubClassicDB.settings.locale
    if supported[configured] then
        return configured
    end

    local gameLocale = ns.GameAPI and ns.GameAPI:GetLocale() or "enUS"
    if gameLocale == "ruRU" then
        return "ruRU"
    end
    return "enUS"
end

function ns:L(key, ...)
    local locale = ns:GetLocaleCode()
    local tableForLocale = ns.locales and ns.locales[locale] or nil
    local english = ns.locales and ns.locales.enUS or nil
    local value = tableForLocale and tableForLocale[key]
        or english and english[key]
        or key
    if select("#", ...) > 0 then
        return string.format(value, ...)
    end
    return value
end

function ns:GetSupportedLocales()
    return { "ruRU", "enUS", "ukUA" }
end

