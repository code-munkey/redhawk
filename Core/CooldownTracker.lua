-- MonkeyTracker: CooldownTracker.lua
-- Manages state for all active (in-cooldown) tracked spells.
-- Data flows: EventHandler → CooldownTracker → MainFrame (UI)

local MT = MonkeyTracker

-- ActiveCDs structure:
--   MT.ActiveCDs[playerName][spellID] = {
--     castTime   = number,   -- GetTime() when cast occurred
--     expireTime = number,   -- castTime + cooldown
--     cooldown   = number,   -- full cooldown duration in seconds
--     spellData  = table,    -- reference to SpellDB entry
--     playerName = string,
--     playerClass= string,
--   }
MT.ActiveCDs = {}

-- Known roster: playerName → class (refreshed on GROUP_ROSTER_UPDATE)
MT.Roster = {}

-- ============================================================
-- Roster Management
-- ============================================================

--- Rebuild the known roster from current group composition.
function MT.OnRosterUpdate()
    local newRoster = {}
    for _, member in ipairs(MT.GetGroupMembers()) do
        newRoster[member.name] = member.class
    end

    -- Prune ActiveCDs for players who left the group
    for playerName in pairs(MT.ActiveCDs) do
        if not newRoster[playerName] then
            MT.Debug("Pruning cooldowns for departed player:", playerName)
            MT.ActiveCDs[playerName] = nil
        end
    end

    MT.Roster = newRoster
    MT.Debug("Roster updated. Members:", MT.TableCount(MT.Roster))
end

-- ============================================================
-- Spell Cast Recording
-- ============================================================

--- Called when CLEU fires a SPELL_CAST_SUCCESS for a tracked spell.
-- @param playerName  string   Source player name
-- @param playerClass string   WoW class token
-- @param spellID     number   Spell ID that was cast
function MT.OnSpellCast(playerName, playerClass, spellID)
    local spellData = MT.SpellDB[spellID]
    if not spellData then return end

    -- Check if this spell is enabled in user settings
    if MT.db and MT.db.disabledSpells and MT.db.disabledSpells[spellID] then
        MT.Debug("Spell disabled by user:", spellData.name)
        return
    end

    -- Check if this player's class matches the expected class for the spell
    -- (guards against spoofed or misidentified casts)
    if spellData.class and playerClass and spellData.class ~= playerClass then
        MT.Debug("Class mismatch for spell", spellData.name, "expected", spellData.class, "got", playerClass)
        return
    end

    local now = GetTime()

    if not MT.ActiveCDs[playerName] then
        MT.ActiveCDs[playerName] = {}
    end

    -- Apply any cooldown reduction from saved config (future feature hook)
    local cd = spellData.cooldown
    if MT.db and MT.db.cooldownOverrides and MT.db.cooldownOverrides[spellID] then
        cd = MT.db.cooldownOverrides[spellID]
    end

    MT.Debug("Recording CD:", playerName, spellData.name, "for", cd, "seconds")

    MT.ActiveCDs[playerName][spellID] = {
        castTime    = now,
        expireTime  = now + cd,
        cooldown    = cd,
        spellData   = spellData,
        playerName  = playerName,
        playerClass = playerClass or spellData.class,
    }

    -- Notify UI that data changed (if UI is ready)
    if MT.MainFrame and MT.MainFrame.OnDataChanged then
        MT.MainFrame.OnDataChanged()
    end
end

-- ============================================================
-- Data Access for UI
-- ============================================================

--- Returns a flat, sorted list of active cooldown entries for display.
-- Entries are sorted by: remaining time ascending (soonest ready first).
-- Expired entries (remain <= 0) are pruned here.
-- @return table[]  List of active CD entries
function MT.GetActiveCooldowns()
    local now = GetTime()
    local list = {}

    local overrides = MT.db and MT.db.cooldownOverrides or {}
    local disabled  = MT.db and MT.db.disabledSpells or {}

    -- Clean up expired entries
    for playerName, spells in pairs(MT.ActiveCDs) do
        for spellID, entry in pairs(spells) do
            if entry.expireTime - now <= 0 then
                spells[spellID] = nil
            end
        end
        if not next(spells) then
            MT.ActiveCDs[playerName] = nil
        end
    end

    -- Add all abilities from roster
    for playerName, playerClass in pairs(MT.Roster) do
        for spellID, spellData in pairs(MT.SpellDB) do
            if spellData.class == playerClass and not disabled[spellID] then
                local cd = overrides[spellID] or spellData.cooldown
                local remaining = 0
                local castTime = 0
                local expireTime = 0

                local activeSpells = MT.ActiveCDs[playerName]
                if activeSpells and activeSpells[spellID] then
                    local entry = activeSpells[spellID]
                    remaining = math.max(0, entry.expireTime - now)
                    castTime = entry.castTime
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

--- Force-clear a specific cooldown entry (e.g. on /mt reset).
function MT.PurgeCooldown(playerName, spellID)
    if MT.ActiveCDs[playerName] then
        MT.ActiveCDs[playerName][spellID] = nil
        if not next(MT.ActiveCDs[playerName]) then
            MT.ActiveCDs[playerName] = nil
        end
    end
end

--- Clear all tracked cooldowns (e.g. on zone change or wipe).
function MT.ClearAllCooldowns()
    MT.ActiveCDs = {}
    MT.Debug("All cooldowns cleared.")
end

-- ============================================================
-- Helper
-- ============================================================

function MT.TableCount(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end
