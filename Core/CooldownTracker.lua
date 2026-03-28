-- MonkeyTracker: CooldownTracker.lua
-- Manages state for all active (in-cooldown) tracked spells.
-- Data flows: EventHandler → CooldownTracker → MainFrame (UI)

-- ActiveCDs structure:
--   RAPE.ActiveCDs[playerName][spellID] = {
--     castTime   = number,   -- GetTime() when cast occurred
--     expireTime = number,   -- castTime + cooldown
--     cooldown   = number,   -- full cooldown duration in seconds
--     spellData  = table,    -- reference to SpellDB entry
--     playerName = string,
--     playerClass= string,
--   }
RAPE.ActiveCDs = {}

-- Known roster: playerName → class (refreshed on GROUP_ROSTER_UPDATE)
RAPE.Roster = {}

-- ============================================================
-- Roster Management
-- ============================================================

--- Rebuild the known roster from current group composition.
function RAPE.OnRosterUpdate()
    local newRoster = {}
    for _, member in ipairs(RAPE.GetGroupMembers()) do
        newRoster[member.name] = member.class
    end

    -- Prune ActiveCDs and PlayerSpells for players who left the group
    for playerName in pairs(RAPE.ActiveCDs) do
        if not newRoster[playerName] then
            RAPE.ActiveCDs[playerName] = nil
        end
    end
    for playerName in pairs(RAPE.PlayerSpells) do
        if not newRoster[playerName] then
            RAPE.PlayerSpells[playerName] = nil
        end
    end

    RAPE.Roster = newRoster

    -- Prune void marked state for players no longer in group
    if RAPE.PruneVoidMarked then
        RAPE.PruneVoidMarked()
    end

    RAPE.Debug("Roster updated. Members:", RAPE.TableCount(RAPE.Roster))
end

-- ============================================================
-- Spell Cast Recording
-- ============================================================

--- Called when CLEU fires a SPELL_CAST_SUCCESS for a tracked spell.
-- @param playerName  string   Source player name
-- @param playerClass string   WoW class token
-- @param spellID     number   Spell ID that was cast
function RAPE.OnSpellCast(playerName, playerClass, spellID)
    local spellData = RAPE.SpellDB[spellID]
    if not spellData then return end

    -- Check if this spell is enabled in user settings
    if RAPE.db and RAPE.db.disabledSpells and RAPE.db.disabledSpells[spellID] then
        RAPE.Debug("Spell disabled by user:", spellData.name)
        return
    end

    -- Check if this player's class matches the expected class for the spell
    -- (guards against spoofed or misidentified casts)
    if spellData.class and playerClass and spellData.class ~= playerClass then
        RAPE.Debug("Class mismatch for spell", spellData.name, "expected", spellData.class, "got", playerClass)
        return
    end

    local now = GetTime()

    if not RAPE.ActiveCDs[playerName] then
        RAPE.ActiveCDs[playerName] = {}
    end

    -- Use the player's reported cooldown if available, else SpellDB default
    local cd = spellData.cooldown
    if RAPE.PlayerSpells[playerName] and RAPE.PlayerSpells[playerName][spellID] then
        cd = RAPE.PlayerSpells[playerName][spellID]
    end
    if RAPE.db and RAPE.db.cooldownOverrides and RAPE.db.cooldownOverrides[spellID] then
        cd = RAPE.db.cooldownOverrides[spellID]
    end

    RAPE.Debug("Recording CD:", playerName, spellData.name, "for", cd, "seconds")

    RAPE.ActiveCDs[playerName][spellID] = {
        castTime    = now,
        expireTime  = now + cd,
        cooldown    = cd,
        spellData   = spellData,
        playerName  = playerName,
        playerClass = playerClass or spellData.class,
    }

    -- Notify UI that data changed (if UI is ready)
    if RAPE.MainFrame and RAPE.MainFrame.OnDataChanged then
        RAPE.MainFrame.OnDataChanged()
    end
end

-- ============================================================
-- Data Access for UI
-- ============================================================

--- Returns a flat, sorted list of active cooldown entries for display.
-- Entries are sorted by: remaining time ascending (soonest ready first).
-- Expired entries (remain <= 0) are pruned here.
-- @return table[]  List of active CD entries
function RAPE.GetActiveCooldowns()
    local now = GetTime()
    local list = {}

    local overrides = RAPE.db and RAPE.db.cooldownOverrides or {}
    local disabled  = RAPE.db and RAPE.db.disabledSpells or {}

    -- Clean up expired entries
    for playerName, spells in pairs(RAPE.ActiveCDs) do
        for spellID, entry in pairs(spells) do
            if entry.expireTime - now <= 0 then
                spells[spellID] = nil
            end
        end
        if not next(spells) then
            RAPE.ActiveCDs[playerName] = nil
        end
    end

    -- Add only spells players have reported having
    for playerName, playerClass in pairs(RAPE.Roster) do
        local knownSpells = RAPE.PlayerSpells[playerName]
        if knownSpells then
            for spellID, cd in pairs(knownSpells) do
                local spellData = RAPE.SpellDB[spellID]
                if spellData and not disabled[spellID] then
                    cd = overrides[spellID] or cd
                    local remaining, castTime, expireTime = 0, 0, 0
                    local activeSpells = RAPE.ActiveCDs[playerName]
                    if activeSpells and activeSpells[spellID] then
                        local entry = activeSpells[spellID]
                        remaining  = math.max(0, entry.expireTime - now)
                        castTime   = entry.castTime
                        expireTime = entry.expireTime
                    end
                    table.insert(list, {
                        playerName  = playerName,
                        playerClass = playerClass,
                        spellID     = spellID,
                        spellData   = spellData,
                        remaining   = remaining,
                        cooldown    = cd,
                        castTime    = castTime,
                        expireTime  = expireTime,
                    })
                end
            end
        end
    end

    -- Sort logic:
    -- 1. Available spells (remaining <= 0) go to the top.
    --    They are sorted by Class -> PlayerName -> SpellName
    -- 2. On CD spells (remaining > 0) go to the bottom.
    --    They are sorted by expireTime (soonest to expire first).
    --    In case of ties, fallback to deterministic Class -> PlayerName -> SpellName.
    table.sort(list, function(a, b)
        local aAvail = (a.remaining <= 0)
        local bAvail = (b.remaining <= 0)

        if aAvail ~= bAvail then
            return aAvail -- Available comes first
        end

        if aAvail then
            -- Both available
            if a.playerClass == b.playerClass then
                if a.playerName == b.playerName then
                    return a.spellData.name < b.spellData.name
                end
                return a.playerName < b.playerName
            end
            return (a.playerClass or "") < (b.playerClass or "")
        else
            -- Both on CD
            if a.expireTime == b.expireTime then
                if a.playerClass == b.playerClass then
                    if a.playerName == b.playerName then
                        return a.spellData.name < b.spellData.name
                    end
                    return a.playerName < b.playerName
                end
                return (a.playerClass or "") < (b.playerClass or "")
            end
            return a.expireTime < b.expireTime
        end
    end)

    return list
end

--- Force-clear a specific cooldown entry (e.g. on /RAPE reset).
function RAPE.PurgeCooldown(playerName, spellID)
    if RAPE.ActiveCDs[playerName] then
        RAPE.ActiveCDs[playerName][spellID] = nil
        if not next(RAPE.ActiveCDs[playerName]) then
            RAPE.ActiveCDs[playerName] = nil
        end
    end
end

--- Clear all tracked cooldowns (e.g. on zone change or wipe).
function RAPE.ClearAllCooldowns()
    RAPE.ActiveCDs = {}
    RAPE.Debug("All cooldowns cleared.")
end

-- ============================================================
-- Helper
-- ============================================================

function RAPE.TableCount(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end
