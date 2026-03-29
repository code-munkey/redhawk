-- MonkeyTracker: Utils.lua
-- Shared helper functions.

-- ============================================================
-- Time Formatting
-- ============================================================

--- Format seconds into a human-readable countdown string.
-- @param seconds number  Remaining seconds.
-- @return string         e.g. "2:30", "45s"
function RAPE.FormatTime(seconds)
    seconds = math.max(0, seconds)
    if seconds >= 60 then
        local m = math.floor(seconds / 60)
        local s = math.floor(seconds % 60)
        return string.format("%d:%02d", m, s)
    else
        return string.format("%ds", math.floor(seconds))
    end
end

-- ============================================================
-- Class Colors
-- ============================================================

--- Returns RGB for a given class token.
-- Falls back to white for unknown / nil class.
-- @param class string  e.g. "DRUID", "PALADIN"
-- @return number r, number g, number b
function RAPE.GetClassColor(class)
    if not class then return 1, 1, 1 end
    local color = (RAID_CLASS_COLORS or C_ClassColor.GetClassColor) and C_ClassColor.GetClassColor(class)
    if color then
        return color.r, color.g, color.b
    end
    -- Hardcoded fallback palette
    local fallback = {
        DRUID       = {0.78, 0.48, 0.10},
        PALADIN     = {0.96, 0.55, 0.73},
        PRIEST      = {1.00, 1.00, 1.00},
        SHAMAN      = {0.00, 0.44, 0.87},
        MONK        = {0.00, 1.00, 0.60},
        EVOKER      = {0.20, 0.58, 0.50},
        DEATHKNIGHT = {0.77, 0.12, 0.23},
        DEMONHUNTER = {0.64, 0.19, 0.79},
        WARRIOR     = {0.78, 0.61, 0.43},
        HUNTER      = {0.67, 0.83, 0.45},
        MAGE        = {0.25, 0.78, 0.92},
        ROGUE       = {1.00, 0.96, 0.41},
        WARLOCK     = {0.53, 0.53, 0.93},
        TINKER      = {0.40, 0.80, 0.90}, -- Midnight new class placeholder
    }
    local c = fallback[class] or {1, 1, 1}
    return c[1], c[2], c[3]
end

-- ============================================================
-- Cooldown progress → color gradient
-- ============================================================

--- Returns a red/yellow/green color based on progress 0→1.
-- 0 = just used (red), 1 = fully ready (green).
-- @param progress number  0.0 to 1.0
-- @return number r, number g, number b
function RAPE.GetCooldownColor(progress)
    progress = math.min(1, math.max(0, progress))
    -- Red → Yellow → Green
    if progress < 0.5 then
        -- Red to Yellow
        local t = progress / 0.5
        return 1.0, t * 0.85, 0.0
    else
        -- Yellow to Green
        local t = (progress - 0.5) / 0.5
        return 1.0 - t, 0.85, 0.0
    end
end

-- ============================================================
-- Roster Helpers
-- ============================================================

--- Return a table of { name, class, unit } for all group members.
-- @return table[]
function RAPE.GetGroupMembers()
    local members = {}
    local prefix, count

    if IsInRaid() then
        prefix, count = "raid", GetNumGroupMembers()
    elseif IsInGroup() then
        prefix, count = "party", GetNumSubgroupMembers()
        -- Add self when in a party (party1..4 doesn't include self)
        local pName = UnitName("player")
        local _, pClass = UnitClass("player")
        if pName and pClass then
            local shortName = strsplit("-", pName)
            table.insert(members, { name = shortName, class = pClass, unit = "player" })
        end
    else
        -- Solo: track self only
        local pName = UnitName("player")
        local _, pClass = UnitClass("player")
        if pName and pClass then
            local shortName = strsplit("-", pName)
            table.insert(members, { name = shortName, class = pClass, unit = "player" })
        end
        return members
    end

    for i = 1, count do
        local unit = prefix .. i
        local name = UnitName(unit)
        local _, class = UnitClass(unit)
        if name and class and UnitIsConnected(unit) then
            local shortName = strsplit("-", name)
            table.insert(members, { name = shortName, class = class, unit = unit })
        end
    end

    return members
end

-- ============================================================
-- Debug
-- ============================================================

--- Print a debug message to chat if debug mode is on.
function RAPE.Debug(...)
    if RAPE.db and RAPE.db.debugMode then
        print("|cff888888[RAPE Debug]|r", ...)
    end
end

--- Print an error/info message (always).
function RAPE.Print(...)
    print("|cff4fc3f7[RAPE]|r", ...)
end

function RAPE.UpdateRosterData()
    local newRoster = {}
    for i = 1, GetNumGroupMembers(), 1 do
        name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(i);
        newRoster[i] = {
            name = name,
            rank = rank,
            subgroup = subgroup,
            level = level,
            class = string.upper(class),
            online = online,
            isDead = isDead,
            role = role,
            isML = isML
        }
    end
    RAPE.RaidRoster = newRoster
end

RAPE.RaidRoster = {

}