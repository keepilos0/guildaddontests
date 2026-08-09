local _, ns = ...

local Validation = {}
ns.Validation = Validation

local function clean(value, maximum)
    local text = tostring(value or "")
    text = text:gsub("[%c]", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if maximum and #text > maximum then
        text = text:sub(1, maximum)
    end
    return text
end

local function numberInRange(value, minimum, maximum)
    local number = tonumber(value)
    if not number or number < minimum or number > maximum then
        return nil
    end
    return math.floor(number)
end

function Validation:Clean(value, maximum)
    return clean(value, maximum)
end

function Validation:Request(values)
    local title = clean(values.title, 80)
    local description = clean(values.description, 500)
    local category = values.category
    local durationHours = numberInRange(values.durationHours or 24, 1, 168)
    local allowedDurations = { [1] = true, [6] = true, [12] = true, [24] = true,
        [72] = true, [168] = true }
    local allowed = { help = true, materials = true, question = true }
    if title == "" or description == "" or not allowed[category]
        or not durationHours or not allowedDurations[durationHours] then
        return nil, "invalid-request"
    end
    return {
        title = title,
        description = description,
        category = category,
        durationHours = durationHours,
    }
end

function Validation:Group(values)
    local title = clean(values.title, 80)
    local description = clean(values.description, 500)
    local size = numberInRange(values.size or 5, 2, 40)
    local startAt = tonumber(values.startAt) or ns.GameAPI:Now()
    if title == "" or description == "" or not size then
        return nil, "invalid-group"
    end
    return {
        title = title,
        description = description,
        size = size,
        roles = clean(values.roles, 120),
        minLevel = numberInRange(values.minLevel or 1, 1, 60) or 1,
        maxLevel = numberInRange(values.maxLevel or 60, 1, 60) or 60,
        startAt = startAt,
    }
end

function Validation:Task(values)
    local title = clean(values.title, 80)
    local description = clean(values.description, 500)
    local goal = numberInRange(values.goal, 1, 1000000)
    local respect = numberInRange(values.respect or 0, 0, 10000)
    if title == "" or description == "" or not goal or not respect then
        return nil, "invalid-task"
    end
    return { title = title, description = description, goal = goal, respect = respect }
end

function Validation:Profile(values)
    return {
        roles = clean(values.roles, 120),
        professions = clean(values.professions, 160),
        mainCharacter = clean(values.mainCharacter, 80),
        comment = clean(values.comment, 300),
        readyToHelp = values.readyToHelp and true or false,
    }
end

function Validation:Contribution(values)
    local amount = numberInRange(values.amount, 1, 1000000)
    if not amount then
        return nil, "invalid-contribution"
    end
    return { amount = amount, comment = clean(values.comment, 300) }
end
