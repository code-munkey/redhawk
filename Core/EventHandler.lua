-- MonkeyTracker: EventHandler.lua
-- Registers WoW events and dispatches to appropriate handlers.

local MT = MonkeyTracker

local ADDON_MSG_PREFIX = "MT_CD"
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
-- Broadcast own cast to group
-- ============================================================

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
        end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        OnPlayerSpellCastSucceeded(event, ...)

    elseif event == "CHAT_MSG_ADDON" then
        OnAddonMessage(...)

    elseif event == "PLAYER_LOGIN" then
        MT.OnPlayerLogin()
        RefreshUnitEventRegistrations()

    elseif event == "GROUP_ROSTER_UPDATE" then
        MT.OnRosterUpdate()
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
