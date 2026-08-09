local _, ns = ...

local Profiles = ns:RegisterModule("Profiles", {})

function Profiles:Get(characterName)
    characterName = characterName or ns.GameAPI:GetPlayerName()
    for _, profile in pairs(ns.Store:GetCollection("profiles") or {}) do
        if profile.owner == characterName then
            return profile
        end
    end
    return nil
end

function Profiles:Save(values)
    local cleaned = ns.Validation:Profile(values)
    if cleaned.mainCharacter ~= "" then
        cleaned.mainCharacter = ns.GameAPI:NormalizeCharacterName(cleaned.mainCharacter)
    end
    local localizedClass, classFile = ns.GameAPI:GetPlayerClass()
    cleaned.level = ns.GameAPI:GetPlayerLevel()
    cleaned.className = localizedClass
    cleaned.classFile = classFile
    cleaned.mainConfirmed = cleaned.mainCharacter == ""
    local existing = self:Get()
    if existing then
        return ns.Store:Update("profiles", existing.id, cleaned)
    end
    return ns.Store:Create("profiles", cleaned)
end

function Profiles:ConfirmAlt(profileId)
    local profile = ns.Store:Get("profiles", profileId)
    if not profile or profile.mainCharacter ~= ns.GameAPI:GetPlayerName() then
        return nil, "permission"
    end
    return ns.Store:ControlledUpdate("profiles", profileId, { mainConfirmed = true })
end
