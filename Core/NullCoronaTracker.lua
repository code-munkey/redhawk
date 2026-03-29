-- MonkeyTracker: NullCoronaTracker.lua
-- Tracks the Null Corona (1233865) healing absorb debuff during the Crown of the Cosmos encounter.

RAPE.NullCorona = {} -- [playerName] = { remaining = number, initial = number, gainTime = number, class = string }

local NULL_CORONA_SPELL_ID = 1233865

-- ============================================================
-- CLEU Dispatch
-- ============================================================

function RAPE.OnCombatLogEvent(...)
    local timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = select(1, ...)
    
    if not destName then return end

    -- Extract shortName for our tracking table
    local shortName = strsplit("-", destName)
    local playerClass = RAPE.Roster[shortName] or "UNKNOWN"

    -- SPELL_AURA_APPLIED / SPELL_AURA_REFRESH
    if subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH" then
        local spellId = select(12, ...)
        if spellId == NULL_CORONA_SPELL_ID then
            local amount = select(16, ...) or 0 -- Absorb amount is usually arg 16

            RAPE.NullCorona[shortName] = {
                remaining = amount,
                initial   = amount,
                gainTime  = GetTime(),
                class     = playerClass,
            }

            RAPE.Debug("Null Corona GAIN on", shortName, "Amount:", amount)
            if RAPE.NullCoronaFrame and RAPE.NullCoronaFrame.Refresh then
                RAPE.NullCoronaFrame.Refresh()
            end
        end

    -- SPELL_AURA_REMOVED
    elseif subevent == "SPELL_AURA_REMOVED" then
        local spellId = select(12, ...)
        if spellId == NULL_CORONA_SPELL_ID then
            if RAPE.NullCorona[shortName] then
                RAPE.NullCorona[shortName] = nil
                RAPE.Debug("Null Corona FADE on", shortName)

                if RAPE.NullCoronaFrame and RAPE.NullCoronaFrame.Refresh then
                    RAPE.NullCoronaFrame.Refresh()
                end
            end
        end

    -- SPELL_HEAL_ABSORBED (Healing absorbed by the debuff)
    elseif subevent == "SPELL_HEAL_ABSORBED" then
        -- In Retail WoW, SPELL_HEAL_ABSORBED arguments after destRaidFlags are:
        -- arg12: spellId (the heal)
        -- arg13: spellName
        -- arg14: spellSchool
        -- arg15: extraSpellId (the absorb debuff)
        -- arg16: extraSpellName
        -- arg17: extraSpellSchool
        -- arg18: amount
        local absorbSpellId = select(15, ...)
        if absorbSpellId == NULL_CORONA_SPELL_ID then
            local absorbedAmount = select(18, ...) or 0
            if RAPE.NullCorona[shortName] then
                RAPE.NullCorona[shortName].remaining = math.max(0, RAPE.NullCorona[shortName].remaining - absorbedAmount)
                
                RAPE.Debug("Null Corona HEAL ABSORBED on", shortName, "Absorbed:", absorbedAmount, "Remaining:", RAPE.NullCorona[shortName].remaining)
                
                if RAPE.NullCoronaFrame and RAPE.NullCoronaFrame.Refresh then
                    RAPE.NullCoronaFrame.Refresh()
                end
            end
        end
    end
end

-- ============================================================
-- Data access for UI
-- ============================================================

function RAPE.GetNullCoronaPlayers()
    local list = {}
    for playerName, data in pairs(RAPE.NullCorona) do
        table.insert(list, {
            name      = playerName,
            class     = data.class,
            remaining = data.remaining,
            initial   = data.initial,
            gainTime  = data.gainTime,
        })
    end

    -- Sort by most remaining shield first
    table.sort(list, function(a, b)
        return a.remaining > b.remaining
    end)

    return list
end

-- ============================================================
-- Test Helper
-- ============================================================

function RAPE.TestNullCorona(action, targetName, amount)
    targetName = targetName or strsplit("-", UnitName("player"))
    local playerClass = RAPE.Roster[targetName] or "UNKNOWN"

    action = (action or ""):lower()
    
    if action == "add" then
        amount = amount or 1000000
        RAPE.NullCorona[targetName] = {
            remaining = amount,
            initial   = amount,
            gainTime  = GetTime(),
            class     = playerClass,
        }
        RAPE.Print("|cffff4444[Test]|r Added Null Corona to", targetName)

    elseif action == "absorb" then
        amount = amount or 100000
        if RAPE.NullCorona[targetName] then
            RAPE.NullCorona[targetName].remaining = math.max(0, RAPE.NullCorona[targetName].remaining - amount)
            RAPE.Print("|cffff4444[Test]|r Absorbed", amount, "on", targetName, "Remaining:", RAPE.NullCorona[targetName].remaining)
        end

    elseif action == "remove" then
        RAPE.NullCorona[targetName] = nil
        RAPE.Print("|cffff4444[Test]|r Removed Null Corona from", targetName)
    end

    if RAPE.NullCoronaFrame and RAPE.NullCoronaFrame.Refresh then
        RAPE.NullCoronaFrame.Refresh()
    end
end
