-- MonkeyTracker: EventHandler.lua
-- Registers WoW events and dispatches to appropriate handlers.

local MT = MonkeyTracker

local ADDON_MSG_PREFIX  = "MT_CD"
local SPELL_LIST_PREFIX = "MT_SL"
local SPELL_REQ_PREFIX  = "MT_REQ"
local VERSION_PREFIX    = "MT_VER"   -- broadcast: request everyone's version
local VERSION_REPLY     = "MT_VERR"  -- reply: I am on version X
local PLAYER_REFRESH    = "MT_PREF"  -- targeted: ask one player to rebroadcast spells
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
    if IsInGroup(2) then return "INSTANCE_CHAT" end
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
        if IsPlayerSpell(spellID) or IsSpellKnown(spellID, false) then
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
        local spellID, cdStr = pair:match("^(%d+):([%d%.]+)$")
        local spellIDNum, cdNum = tonumber(spellID), tonumber(cdStr)
        if spellIDNum and cdNum and MT.SpellDB[spellIDNum] then
            MT.PlayerSpells[shortName][spellIDNum] = cdNum
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
-- Public: version check, spell list request, per-player refresh
-- ============================================================

function MT.BroadcastVersionCheck()
    if not IsInGroup() then
        MT.Print("Version check: not in a group.")
        return
    end
    MT.Print("|cffffd700[Version Check]|r Sending request... replies will appear below.")
    C_ChatInfo.SendAddonMessage(VERSION_PREFIX, MT.VERSION, GetMsgChannel())
end

function MT.RequestSpellLists()
    MT.BroadcastSpellList()  -- broadcast our own
    if IsInGroup() then
        C_ChatInfo.SendAddonMessage(SPELL_REQ_PREFIX, "req", GetMsgChannel())
        MT.Print("Requesting spell lists from all group members.")
    end
end

function MT.RequestPlayerRefresh(playerName)
    if not playerName or playerName == "" then return end
    if IsInGroup() then
        C_ChatInfo.SendAddonMessage(PLAYER_REFRESH, playerName, GetMsgChannel())
        MT.Print("Requesting spell refresh from:", playerName)
    end
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
            C_ChatInfo.RegisterAddonMessagePrefix(VERSION_PREFIX)
            C_ChatInfo.RegisterAddonMessagePrefix(VERSION_REPLY)
            C_ChatInfo.RegisterAddonMessagePrefix(PLAYER_REFRESH)
        end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        OnPlayerSpellCastSucceeded(event, ...)

    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == ADDON_MSG_PREFIX then
            OnAddonMessage(prefix, message, channel, sender)
        elseif prefix == SPELL_LIST_PREFIX then
            OnAddonSpellList(sender, message)
        elseif prefix == SPELL_REQ_PREFIX then
            MT.BroadcastSpellList()
        elseif prefix == VERSION_PREFIX then
            -- Someone is checking versions — reply with ours
            C_ChatInfo.SendAddonMessage(VERSION_REPLY, MT.VERSION, GetMsgChannel())
        elseif prefix == VERSION_REPLY then
            -- Got a version reply from a group member
            local shortSender = strsplit("-", sender)
            MT.Print(string.format("|cffffd700[Version Check]|r %s: v%s", shortSender, message))
        elseif prefix == PLAYER_REFRESH then
            -- Targeted refresh: only reply if the payload matches our name
            local myName = strsplit("-", UnitName("player") or "")
            if message == myName then
                MT.BroadcastSpellList()
            end
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
