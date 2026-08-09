local _, ns = ...

local News = ns:RegisterModule("News", {})

function News:Create(title, description)
    if not ns.Permissions:IsOfficer() then
        return nil, "permission"
    end
    title = ns.Validation:Clean(title, 80)
    description = ns.Validation:Clean(description, 500)
    if title == "" or description == "" then
        return nil, "invalid"
    end
    return ns.Store:Create("news", { title = title, description = description })
end

function News:List()
    return ns.Store:List("news", false)
end

