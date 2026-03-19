-- MonkeyTracker: EventHandler.lua
-- Registers WoW events and dispatches to appropriate handlers.

local MT = MonkeyTracker

local ADDON_MSG_PREFIX  = "MT_CD"
local SPELL_LIST_PREFIX = "MT_SL"
local SPELL_REQ_PREFIX  = "MT_REQ"
local ADDON_MSG_CHANNEL = "PARTY" -- falls back to RAID when in raid

local eventFrame = CreateFrame("Frame")
MT.EventFrame = eventFrame

local function SafeReg(event)
    local ok, err = pcall(eventFrame.RegisterEvent, eventFrame, event)
    if not ok then MT.Debug("Blocked from registering event:", event) end
    return ok
end

local function RefreshUnitEventRegistrations()
    MT.Debug("Roster known members:", MT.TableCount(MT.Roster))
end

local function GetMsgChannel()
    return IsInRaid() and "RAID" or "PARTY"
end

-- ============================================================
-- Spell list broadcast (what spells this player has talented)
-- ============================================================

function MT.BroadcastSpellList()
    local playerName = strsplit("-", UnitName("player") or "")
    if not playerName or playerName == "" then return end

    local parts = {}
    MT.PlayerSpells[playerName] = {}

    for spellID, spellData in pairs(MT.SpellDB) do
        if IsPlayerSpell(spellID) then
            local cd = spellData.cooldown
            local cdInfo = C_Spell.GetSpellCooldown(spellID)
            if cdInfo and cdInfo.duration and cdInfo.duration > 0 then
                cd = cdInfo.duration
            end
            MT.PlayerSpells[playerName][spellID] = cd
            parts[#parts+1] = spellID..":"..cd
        end
    end

    if #parts == 0 then return end
    local channel = GetMsgChannel()
    if not IsInGroup() then return end  -- no one to broadcast to

    local chunk, len = {}, 0
    for _, part in ipairs(parts) do
        if len + #part + 1 > 240 then
            C_ChatInfo.SendAddonMessage(SPELL_LIST_PREFIX, table.concat(chunk, ","), channel)
            chunk, len = {}, 0
        end
        chunk[#chunk+1] = part
        len = len + #part + 1
    end
    if #chunk > 0 then
        C_ChatInfo.SendAddonMessage(SPELL_LIST_PREFIX, table.concat(chunk, ","), channel)
    end
end

local function OnAddonSpellList(sender, message)
    local shortName = strsplit("-", sender)
    print("[MT] SpellList from sender='"..tostring(sender).."' short='"..tostring(shortName).."' inRoster=", MT.Roster[shortName] ~= nil, "msglen=", #message)
    if not MT.Roster[shortName] then return end
    MT.PlayerSpells[shortName] = MT.PlayerSpells[shortName] or {}
    local count = 0
    for pair in message:gmatch("[^,]+") do
        local spellID, cd = pair:match("^(%d+):(%d+)$")
        spellID, cd = tonumber(spellID), tonumber(cd)
        if spellID and cd and MT.SpellDB[spellID] then
            MT.PlayerSpells[shortName][spellID] = cd
            count = count + 1
        end
    end
    print("[MT] SpellList parsed", count, "spells for", shortName)
    if MT.MainFrame and MT.MainFrame.Refresh then MT.MainFrame.Refresh() end
end

local function BroadcastCast(spellID)
    local channel = GetMsgChannel()
    C_ChatInfo.SendAddonMessage(ADDON_MSG_PREFIX, tostring(spellID), channel)
end

-- ============================================================
-- Handle incoming addon message (cast by another group member)
-- ============================================================

local function OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= ADDON_MSG_PREFIX then return end

    local spellID = tonumber(message)
    if not spellID or not MT.TrackedSpellIDs[spellID] then return end

    local shortName = strsplit("-", sender)
    local playerClass = MT.Roster[shortName]
    if not playerClass then return end

    MT.Debug("AddonMsg CD from:", shortName, spellID)
    MT.OnSpellCast(shortName, playerClass, spellID)
end

-- ============================================================
-- Handle own spell cast (player unit only — unrestricted)
-- ============================================================

local function OnPlayerSpellCastSucceeded(event, unitTarget, castGUID, spellID)
    if unitTarget ~= "player" then return end

    local safeSpellID
    local ok, val = pcall(function() return tonumber(spellID) end)
    if not ok or not val then return end
    safeSpellID = val
    if not safeSpellID or not MT.TrackedSpellIDs[safeSpellID] then return end

    local fullName = UnitName("player")
    if not fullName then return end
    local shortName = strsplit("-", fullName)

    local playerClass = MT.Roster[shortName]
    if not playerClass then return end

    MT.Debug("Own cast:", shortName, safeSpellID)
    MT.OnSpellCast(shortName, playerClass, safeSpellID)
    BroadcastCast(safeSpellID)
end

-- ============================================================
-- Combat / zone state
-- ============================================================

local function OnCombatStart()
    MT.inCombat = true
    MT.Debug("Combat started.")
end

local function OnCombatEnd()
    MT.inCombat = false
    MT.Debug("Combat ended.")
end

local function OnZoneChanged()
    local _, instanceType = IsInInstance()
    if instanceType == "raid" or instanceType == "party" then
        MT.Debug("Entered instance — clearing stale cooldowns.")
        MT.ClearAllCooldowns()
    end
end

-- ============================================================
-- Event dispatch
-- ============================================================

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "MonkeyTracker" then
            MT.OnAddonLoaded()
            SafeReg("PLAYER_LOGIN")
            SafeReg("GROUP_ROSTER_UPDATE")
            SafeReg("PLAYER_REGEN_DISABLED")
            SafeReg("PLAYER_REGEN_ENABLED")
            SafeReg("PLAYER_ENTERING_WORLD")
            SafeReg("CHAT_MSG_ADDON")
            -- Only track own casts via unit event (player only, no restrictions)
            eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
            C_ChatInfo.RegisterAddonMessagePrefix(ADDON_MSG_PREFIX)
            C_ChatInfo.RegisterAddonMessagePrefix(SPELL_LIST_PREFIX)
            C_ChatInfo.RegisterAddonMessagePrefix(SPELL_REQ_PREFIX)
        end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        OnPlayerSpellCastSucceeded(event, ...)

    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, _, sender = ...
        if prefix == ADDON_MSG_PREFIX then
            OnAddonMessage(prefix, message, nil, sender)
        elseif prefix == SPELL_LIST_PREFIX then
            OnAddonSpellList(sender, message)
        elseif prefix == SPELL_REQ_PREFIX then
            -- Someone joined/reloaded and is requesting spell lists — broadcast ours
            MT.BroadcastSpellList()
        end

    elseif event == "PLAYER_LOGIN" then
        MT.OnPlayerLogin()
        MT.BroadcastSpellList()
        if IsInGroup() then
            C_ChatInfo.SendAddonMessage(SPELL_REQ_PREFIX, "req", GetMsgChannel())
        end
        RefreshUnitEventRegistrations()

    elseif event == "GROUP_ROSTER_UPDATE" then
        MT.OnRosterUpdate()
        MT.BroadcastSpellList()
        if IsInGroup() then
            C_ChatInfo.SendAddonMessage(SPELL_REQ_PREFIX, "req", GetMsgChannel())
        end
        RefreshUnitEventRegistrations()
        if MT.MainFrame and MT.MainFrame.Refresh then
            MT.MainFrame.Refresh()
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        OnCombatStart()

    elseif event == "PLAYER_REGEN_ENABLED" then
        OnCombatEnd()

    elseif event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...
        MT.OnRosterUpdate()
        RefreshUnitEventRegistrations()
        if not isInitialLogin and not isReloadingUi then
            OnZoneChanged()
        end
    end
end)

SafeReg("ADDON_LOADED")
