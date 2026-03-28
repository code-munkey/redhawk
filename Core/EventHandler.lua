-- MonkeyTracker: EventHandler.lua
-- Registers WoW events and dispatches to appropriate handlers.

local ADDON_MSG_PREFIX  = "RAPE_CD"
local SPELL_LIST_PREFIX = "RAPE_SL"
local SPELL_REQ_PREFIX  = "RAPE_REQ"
local VERSION_PREFIX    = "RAPE_VER"   -- broadcast: request everyone's version
local VERSION_REPLY     = "RAPE_VERR"  -- reply: I am on version X
local VOID_MARK_PREFIX  = "RAPE_VM"    -- void marked aura gain/fade
local PLAYER_REFRESH    = "RAPE_PREF"  -- targeted: ask one player to rebroadcast spells
local FORCE_SETTING     = "RAPE_FSET"  -- admin: force a setting on all clients
local ADDON_MSG_CHANNEL = "PARTY" -- falls back to RAID when in raid

local ENCOUNTER_ID = 0
local ENCOUNTER_DIFF = 0

local eventFrame = CreateFrame("Frame")
RAPE.EventFrame = eventFrame

local function SafeReg(event)
    local ok, err = pcall(eventFrame.RegisterEvent, eventFrame, event)
    if not ok then RAPE.Debug("Blocked from registering event:", event) end
    return ok
end

local function RefreshUnitEventRegistrations()
    RAPE.Debug("Roster known members:", RAPE.TableCount(RAPE.Roster))
end

local function GetMsgChannel()
    if IsInGroup(2) then return "INSTANCE_CHAT" end
    return IsInRaid() and "RAID" or "PARTY"
end

-- Expose for other modules (e.g. AdminFrame)
RAPE.GetMsgChannel = GetMsgChannel

-- ============================================================
-- Spell list broadcast (what spells this player has talented)
-- ============================================================

function RAPE.BroadcastSpellList()
    local playerName = strsplit("-", UnitName("player") or "")
    if not playerName or playerName == "" then return end

    local parts = {}
    RAPE.PlayerSpells[playerName] = {}

    for spellID, spellData in pairs(RAPE.SpellDB) do
        if C_SpellBook.IsSpellInSpellBook(spellID) then
            local cd = spellData.cooldown
            RAPE.PlayerSpells[playerName][spellID] = cd
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
    --print("[RAPE] SpellList from sender='"..tostring(sender).."' short='"..tostring(shortName).."' inRoster=", RAPE.Roster[shortName] ~= nil, "msglen=", #message)
    if not RAPE.Roster[shortName] then return end
    RAPE.PlayerSpells[shortName] = RAPE.PlayerSpells[shortName] or {}
    local count = 0
    for pair in message:gmatch("[^,]+") do
        local spellID, cdStr = pair:match("^(%d+):([%d%.]+)$")
        local spellIDNum, cdNum = tonumber(spellID), tonumber(cdStr)
        if spellIDNum and cdNum and RAPE.SpellDB[spellIDNum] then
            RAPE.PlayerSpells[shortName][spellIDNum] = cdNum
            count = count + 1
        end
    end
    --print("[RAPE] SpellList parsed", count, "spells for", shortName)
    if RAPE.MainFrame and RAPE.MainFrame.Refresh then RAPE.MainFrame.Refresh() end
end

local function BroadcastCast(spellID)
    local channel = GetMsgChannel()
    C_ChatInfo.SendAddonMessage(ADDON_MSG_PREFIX, tostring(spellID), channel)
end

-- ============================================================
-- Public: version check, spell list request, per-player refresh
-- ============================================================

function RAPE.BroadcastVersionCheck()
    if not IsInGroup() then
        RAPE.Print("Version check: not in a group.")
        return
    end
    -- Reset tracking state
    RAPE.VersionResponses = {}
    RAPE.VersionCheckInProgress = true
    RAPE.VersionCheckTime = GetTime()

    RAPE.Print("|cffffd700[Version Check]|r Sending request... replies will appear below.")
    C_ChatInfo.SendAddonMessage(VERSION_PREFIX, RAPE.VERSION, GetMsgChannel())

    -- After 5 seconds, mark anyone who didn't respond as "Not Installed"
    C_Timer.After(5, function()
        RAPE.VersionCheckInProgress = false
        for name in pairs(RAPE.Roster) do
            if not RAPE.VersionResponses[name] then
                RAPE.VersionResponses[name] = "NOT_INSTALLED"
            end
        end
        -- Refresh admin frame if visible
        if RAPE.AdminFrame and RAPE.AdminFrame.Refresh then
            RAPE.AdminFrame.Refresh()
        end
        RAPE.Print("|cffffd700[Version Check]|r Complete.")
    end)
end

function RAPE.RequestSpellLists()
    RAPE.BroadcastSpellList()  -- broadcast our own
    if IsInGroup() then
        C_ChatInfo.SendAddonMessage(SPELL_REQ_PREFIX, "req", GetMsgChannel())
        RAPE.Print("Requesting spell lists from all group members.")
    end
end

function RAPE.RequestPlayerRefresh(playerName)
    if not playerName or playerName == "" then return end
    if IsInGroup() then
        C_ChatInfo.SendAddonMessage(PLAYER_REFRESH, playerName, GetMsgChannel())
        RAPE.Print("Requesting spell refresh from:", playerName)
    end
end

-- ============================================================
-- Handle incoming addon message (cast by another group member)
-- ============================================================

local function OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= ADDON_MSG_PREFIX then return end

    local spellID = tonumber(message)
    if not spellID or not RAPE.TrackedSpellIDs[spellID] then return end

    local shortName = strsplit("-", sender)
    local playerClass = RAPE.Roster[shortName]
    if not playerClass then return end

    RAPE.Debug("AddonMsg CD from:", shortName, spellID)
    RAPE.OnSpellCast(shortName, playerClass, spellID)
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
    if not safeSpellID or not RAPE.TrackedSpellIDs[safeSpellID] then return end

    local fullName = UnitName("player")
    if not fullName then return end
    local shortName = strsplit("-", fullName)

    local playerClass = RAPE.Roster[shortName]
    if not playerClass then return end

    RAPE.Debug("Own cast:", shortName, safeSpellID)
    RAPE.OnSpellCast(shortName, playerClass, safeSpellID)
    BroadcastCast(safeSpellID)
end

-- ============================================================
-- Combat / zone state
-- ============================================================

local function OnEncounterStart(event, encounterID, encounterName, difficultyID, groupSize)
    ENCOUNTER_ID = encounterID
    ENCOUNTER_DIFF = difficultyID
end

local function OnCombatStart()
    RAPE.inCombat = true
    RAPE.Debug("Combat started.")
end

local function OnCombatEnd()
    RAPE.inCombat = false
    RAPE.Debug("Combat ended.")
end

local function OnZoneChanged()
    local _, instanceType = IsInInstance()
    if instanceType == "raid" or instanceType == "party" then
        RAPE.Debug("Entered instance — clearing stale cooldowns.")
        RAPE.ClearAllCooldowns()
    end
end

-- ============================================================
-- Event dispatch
-- ============================================================

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "RAPE" then
            RAPE.OnAddonLoaded()
            SafeReg("PLAYER_LOGIN")
            SafeReg("GROUP_ROSTER_UPDATE")
            SafeReg("PLAYER_REGEN_DISABLED")
            SafeReg("PLAYER_REGEN_ENABLED")
            SafeReg("PLAYER_ENTERING_WORLD")
            SafeReg("CHAT_MSG_ADDON")
            -- Only track own casts via unit event (player only, no restrictions)
            eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
            eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
            
            C_ChatInfo.RegisterAddonMessagePrefix(ADDON_MSG_PREFIX)
            C_ChatInfo.RegisterAddonMessagePrefix(SPELL_LIST_PREFIX)
            C_ChatInfo.RegisterAddonMessagePrefix(SPELL_REQ_PREFIX)
            C_ChatInfo.RegisterAddonMessagePrefix(VERSION_PREFIX)
            C_ChatInfo.RegisterAddonMessagePrefix(VERSION_REPLY)
            C_ChatInfo.RegisterAddonMessagePrefix(PLAYER_REFRESH)
            C_ChatInfo.RegisterAddonMessagePrefix(VOID_MARK_PREFIX)
            C_ChatInfo.RegisterAddonMessagePrefix(FORCE_SETTING)
        end

    elseif event == "ENCOUNTER_START" then
        OnEncounterStart(event, ...)

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        OnPlayerSpellCastSucceeded(event, ...)

    elseif event == "UNIT_AURA" then
        local unit = ...
        if unit == "player" and RAPE.CheckVoidMarked and ENCOUNTER_ID == RAPE.VOIDSPIRE.BOSSES.IMPERATOR_AVERZIAN then
            RAPE.CheckVoidMarked()
            RAPE.Print("Averzian engaged ...")
        end

    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == ADDON_MSG_PREFIX then
            OnAddonMessage(prefix, message, channel, sender)
        elseif prefix == SPELL_LIST_PREFIX then
            OnAddonSpellList(sender, message)
        elseif prefix == SPELL_REQ_PREFIX then
            RAPE.BroadcastSpellList()
        elseif prefix == VERSION_PREFIX then
            -- Someone is checking versions — reply with ours
            C_ChatInfo.SendAddonMessage(VERSION_REPLY, RAPE.VERSION, GetMsgChannel())
        elseif prefix == VERSION_REPLY then
            -- Got a version reply from a group member
            local shortSender = strsplit("-", sender)
            RAPE.VersionResponses[shortSender] = message
            RAPE.Print(string.format("|cffffd700[Version Check]|r %s: v%s", shortSender, message))
            if RAPE.AdminFrame and RAPE.AdminFrame.Refresh then
                RAPE.AdminFrame.Refresh()
            end
        elseif prefix == FORCE_SETTING then
            -- Received a forced setting from raid leader
            local settingName, settingValue = strsplit("|", message, 2)
            if settingName and settingValue then
                RAPE.Print(string.format("|cffff8800[Admin]|r Raid leader forced setting: %s = %s", settingName, settingValue))
                -- Apply known boolean settings
                if settingName == "debugMode" then
                    RAPE.db.debugMode = (settingValue == "true")
                else
                    -- Store in generic forced settings table for future use
                    RAPE.db.forcedSettings = RAPE.db.forcedSettings or {}
                    RAPE.db.forcedSettings[settingName] = settingValue
                end
            end
        elseif prefix == PLAYER_REFRESH then
            -- Targeted refresh: only reply if the payload matches our name
            local myName = strsplit("-", UnitName("player") or "")
            if message == myName then
                RAPE.BroadcastSpellList()
            end
        elseif prefix == VOID_MARK_PREFIX then
            if RAPE.OnVoidMarkedMessage then
                RAPE.OnVoidMarkedMessage(sender, message)
            end
        end

    elseif event == "PLAYER_LOGIN" then
        RAPE.OnPlayerLogin()
        RAPE.BroadcastSpellList()
        if IsInGroup() then
            C_ChatInfo.SendAddonMessage(SPELL_REQ_PREFIX, "req", GetMsgChannel())
        end
        RefreshUnitEventRegistrations()

    elseif event == "GROUP_ROSTER_UPDATE" then
        RAPE.UpdateRosterData()
        RAPE.OnRosterUpdate()
        RAPE.BroadcastSpellList()
        if IsInGroup() then
            C_ChatInfo.SendAddonMessage(SPELL_REQ_PREFIX, "req", GetMsgChannel())
        end
        RefreshUnitEventRegistrations()
        if RAPE.MainFrame and RAPE.MainFrame.Refresh then
            RAPE.MainFrame.Refresh()
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        OnCombatStart()

    elseif event == "PLAYER_REGEN_ENABLED" then
        OnCombatEnd()

    elseif event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...
        RAPE.OnRosterUpdate()
        RefreshUnitEventRegistrations()
        if not isInitialLogin and not isReloadingUi then
            OnZoneChanged()
        end
    end
end)

SafeReg("ADDON_LOADED")
