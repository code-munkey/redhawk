-- MonkeyTracker: AuraTracker.lua
-- Tracks private auras (e.g. Void Marked) via self-detection + addon broadcast.
-- Each player detects the aura on THEMSELVES and broadcasts GAIN/FADE to the group.

local VOID_MARKED_SPELL_ID = 1280023
local VOID_MARKED_PREFIX   = "RAPE_VM"
local POLL_INTERVAL        = 0.05   -- seconds between combat-poll checks

-- ============================================================
-- State
-- ============================================================

-- RAPE.VoidMarked[playerName] = { gainTime = number, class = string }
-- Populated via addon messages from group members.

local hadAura = false   -- tracks whether WE currently have the aura

-- ============================================================
-- Self-detection: check if the player has Void Marked
-- ============================================================

--- Attempt to detect Void Marked on the player.
-- Tries C_UnitAuras.GetPlayerAuraBySpellID first; if that doesn't work
-- for private auras, falls back to iterating AuraUtil.
-- @return boolean  true if the player currently has Void Marked
local function PlayerHasVoidMarked()
    -- Method 1: Direct lookup (may not work for private auras)
    local aura = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID(VOID_MARKED_SPELL_ID)
    if aura then return true end

    -- Method 2: Iterate debuffs on "player" (fallback)
    -- Use C_UnitAuras API for Midnight compatibility; fall back to UnitDebuff for older clients
    local i = 1
    while true do
        local auraData
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HARMFUL|RAID_PLAYER_DISPELLABLE")
        elseif UnitDebuff then
            local name, _, _, _, _, _, _, _, _, spellId = UnitDebuff("player", i)
            if name then
                auraData = { spellId = spellId }
            end
        end
        if not auraData then break end
        if auraData then return true end
        i = i + 1
    end

    return false
end

-- ============================================================
-- Broadcast helpers
-- ============================================================

local function GetMsgChannel()
    if IsInGroup(2) then return "INSTANCE_CHAT" end
    return IsInRaid() and "RAID" or "PARTY"
end

local function BroadcastVoidMark(status)
    if not IsInGroup() then return end
    C_ChatInfo.SendAddonMessage(VOID_MARKED_PREFIX, status, GetMsgChannel())
    RAPE.Debug("VoidMark broadcast:", status)
end

-- ============================================================
-- Core check — called when aura state may have changed
-- ============================================================

function RAPE.CheckVoidMarked()
    local hasAura = PlayerHasVoidMarked()

    if hasAura and not hadAura then
        -- Just gained the aura
        hadAura = true
        BroadcastVoidMark("GAIN")
        -- Also record locally
        local playerName = strsplit("-", UnitName("player") or "")
        local _, playerClass = UnitClass("player")
        if playerName and playerName ~= "" then
            RAPE.VoidMarked[playerName] = {
                gainTime = GetTime(),
                class    = playerClass or "UNKNOWN",
            }
        end
        RAPE.Debug("VoidMarked GAINED on self")
        if RAPE.VoidMarkedFrame and RAPE.VoidMarkedFrame.Refresh then
            RAPE.VoidMarkedFrame.Refresh()
        end

    elseif not hasAura and hadAura then
        -- Aura faded
        hadAura = false
        BroadcastVoidMark("FADE")
        local playerName = strsplit("-", UnitName("player") or "")
        if playerName then
            RAPE.VoidMarked[playerName] = nil
        end
        RAPE.Debug("VoidMarked FADED on self")
        if RAPE.VoidMarkedFrame and RAPE.VoidMarkedFrame.Refresh then
            RAPE.VoidMarkedFrame.Refresh()
        end
    end
end

-- ============================================================
-- Handle incoming addon messages from other group members
-- ============================================================

function RAPE.OnVoidMarkedMessage(sender, message)
    local shortName = strsplit("-", sender)
    if not RAPE.Roster[shortName] then return end

    if message == "GAIN" then
        local playerClass = RAPE.Roster[shortName]
        RAPE.VoidMarked[shortName] = {
            gainTime = GetTime(),
            class    = playerClass or "UNKNOWN",
        }
        RAPE.Debug("VoidMarked GAIN from:", shortName)

    elseif message == "FADE" then
        RAPE.VoidMarked[shortName] = nil
        RAPE.Debug("VoidMarked FADE from:", shortName)
    end

    if RAPE.VoidMarkedFrame and RAPE.VoidMarkedFrame.Refresh then
        RAPE.VoidMarkedFrame.Refresh()
    end
end

-- ============================================================
-- Combat polling fallback
-- ============================================================

local pollFrame = CreateFrame("Frame")
local pollElapsed = 0
pollFrame:SetScript("OnUpdate", function(self, dt)
    if not RAPE.inCombat then return end
    pollElapsed = pollElapsed + dt
    if pollElapsed >= POLL_INTERVAL then
        pollElapsed = 0
        RAPE.CheckVoidMarked()
    end
end)

-- ============================================================
-- Data access for UI
-- ============================================================

--- Returns a sorted list of currently Void Marked players.
-- @return table[]  { { name=string, class=string, elapsed=number } }
function RAPE.GetVoidMarkedPlayers()
    local now  = GetTime()
    local list = {}

    for playerName, data in pairs(RAPE.VoidMarked) do
        table.insert(list, {
            name    = playerName,
            class   = data.class,
            elapsed = now - data.gainTime,
        })
    end

    table.sort(list, function(a, b)
        return a.elapsed < b.elapsed   -- newest marks first
    end)

    return list
end

-- ============================================================
-- Cleanup: remove marks for players who left the group
-- ============================================================

function RAPE.PruneVoidMarked()
    for playerName in pairs(RAPE.VoidMarked) do
        if not RAPE.Roster[playerName] then
            RAPE.VoidMarked[playerName] = nil
        end
    end
end

-- ============================================================
-- Test/debug helper: simulate a gain/fade cycle
-- ============================================================

function RAPE.TestVoidMark(action)
    local playerName = strsplit("-", UnitName("player") or "")
    local _, playerClass = UnitClass("player")
    if not playerName or playerName == "" then
        RAPE.Print("Cannot test: no player name.")
        return
    end

    action = (action or ""):lower()

    if action == "gain" then
        RAPE.VoidMarked[playerName] = {
            gainTime = GetTime(),
            class    = playerClass or "UNKNOWN",
        }
        BroadcastVoidMark("GAIN")
        RAPE.Print("|cffff4444[Test]|r Simulated Void Marked GAIN on " .. playerName)
    elseif action == "fade" then
        RAPE.VoidMarked[playerName] = nil
        BroadcastVoidMark("FADE")
        RAPE.Print("|cffff4444[Test]|r Simulated Void Marked FADE on " .. playerName)
    else
        -- Toggle
        if RAPE.VoidMarked[playerName] then
            RAPE.VoidMarked[playerName] = nil
            BroadcastVoidMark("FADE")
            RAPE.Print("|cffff4444[Test]|r Simulated Void Marked FADE on " .. playerName)
        else
            RAPE.VoidMarked[playerName] = {
                gainTime = GetTime(),
                class    = playerClass or "UNKNOWN",
            }
            BroadcastVoidMark("GAIN")
            RAPE.Print("|cffff4444[Test]|r Simulated Void Marked GAIN on " .. playerName)
        end
    end

    if RAPE.VoidMarkedFrame and RAPE.VoidMarkedFrame.Refresh then
        RAPE.VoidMarkedFrame.Refresh()
    end
end
