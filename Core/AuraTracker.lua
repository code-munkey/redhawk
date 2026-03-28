-- MonkeyTracker: AuraTracker.lua
-- Tracks private auras (e.g. Void Marked) via self-detection + addon broadcast.
-- Each player detects the aura on THEMSELVES and broadcasts GAIN/FADE to the group.

local VOID_MARKED_SPELL_ID = 1280023
local VOID_MARKED_PREFIX   = "RAPE_VM"
local POLL_INTERVAL        = 0.05   -- seconds between combat-poll checks

-- ============================================================
-- State
-- ============================================================

-- RAPE.VoidMarked[playerName][auraInstanceID] = { gainTime = number, class = string }
-- Populated via addon messages from group members.

local myActiveAuras = {}   -- tracks which auraInstanceIDs WE currently have

-- ============================================================
-- Self-detection: get void marked auras on the player
-- ============================================================

local function GetPlayerVoidMarkedInstances()
    local instances = {}
    local i = 1
    while true do
        local auraData
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HARMFUL|RAID_PLAYER_DISPELLABLE")
            if not auraData then break end
            
            -- As long as it matches the filter, we know it's the right one
            if auraData.auraInstanceID then
                instances[auraData.auraInstanceID] = true
            end
        else
            break
        end

        i = i + 1
    end

    return instances
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
    local currentInstances = GetPlayerVoidMarkedInstances()
    local changed = false

    -- Check for new instances
    for instanceID in pairs(currentInstances) do
        if not myActiveAuras[instanceID] then
            myActiveAuras[instanceID] = true
            BroadcastVoidMark("GAIN:" .. instanceID)

            local playerName = strsplit("-", UnitName("player") or "")
            local _, playerClass = UnitClass("player")
            if playerName and playerName ~= "" then
                RAPE.VoidMarked[playerName] = RAPE.VoidMarked[playerName] or {}
                RAPE.VoidMarked[playerName][instanceID] = {
                    gainTime = GetTime(),
                    class    = playerClass or "UNKNOWN",
                }
            end
            RAPE.Debug("VoidMarked GAINED on self:", instanceID)
            changed = true
        end
    end

    -- Check for faded instances
    for instanceID in pairs(myActiveAuras) do
        if not currentInstances[instanceID] then
            myActiveAuras[instanceID] = nil
            BroadcastVoidMark("FADE:" .. instanceID)

            local playerName = strsplit("-", UnitName("player") or "")
            if playerName and RAPE.VoidMarked[playerName] then
                RAPE.VoidMarked[playerName][instanceID] = nil
                if next(RAPE.VoidMarked[playerName]) == nil then
                    RAPE.VoidMarked[playerName] = nil
                end
            end
            RAPE.Debug("VoidMarked FADED on self:", instanceID)
            changed = true
        end
    end

    if changed and RAPE.VoidMarkedFrame and RAPE.VoidMarkedFrame.Refresh then
        RAPE.VoidMarkedFrame.Refresh()
    end
end

-- ============================================================
-- Handle incoming addon messages from other group members
-- ============================================================

function RAPE.OnVoidMarkedMessage(sender, message)
    local shortName = strsplit("-", sender)
    if not RAPE.Roster[shortName] then return end

    local action, instanceID = strsplit(":", message)
    if not instanceID then instanceID = "unknown" end

    if action == "GAIN" then
        local playerClass = RAPE.Roster[shortName]
        RAPE.VoidMarked[shortName] = RAPE.VoidMarked[shortName] or {}
        RAPE.VoidMarked[shortName][instanceID] = {
            gainTime = GetTime(),
            class    = playerClass or "UNKNOWN",
        }
        RAPE.Debug("VoidMarked GAIN from:", shortName, "ID:", instanceID)

    elseif action == "FADE" then
        if RAPE.VoidMarked[shortName] then
            RAPE.VoidMarked[shortName][instanceID] = nil
            if next(RAPE.VoidMarked[shortName]) == nil then
                RAPE.VoidMarked[shortName] = nil
            end
        end
        RAPE.Debug("VoidMarked FADE from:", shortName, "ID:", instanceID)
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
-- @return table[]  { { name=string, class=string, elapsed=number, instanceID=string } }
function RAPE.GetVoidMarkedPlayers()
    local now  = GetTime()
    local list = {}

    for playerName, instances in pairs(RAPE.VoidMarked) do
        for instanceID, data in pairs(instances) do
            table.insert(list, {
                name       = playerName,
                class      = data.class,
                elapsed    = now - data.gainTime,
                instanceID = instanceID,
            })
        end
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
    local testInstanceID = "test-1234"

    if action == "gain" then
        RAPE.VoidMarked[playerName] = RAPE.VoidMarked[playerName] or {}
        RAPE.VoidMarked[playerName][testInstanceID] = {
            gainTime = GetTime(),
            class    = playerClass or "UNKNOWN",
        }
        BroadcastVoidMark("GAIN:" .. testInstanceID)
        RAPE.Print("|cffff4444[Test]|r Simulated Void Marked GAIN on " .. playerName)
    elseif action == "fade" then
        if RAPE.VoidMarked[playerName] then
            RAPE.VoidMarked[playerName][testInstanceID] = nil
            if next(RAPE.VoidMarked[playerName]) == nil then
                RAPE.VoidMarked[playerName] = nil
            end
        end
        BroadcastVoidMark("FADE:" .. testInstanceID)
        RAPE.Print("|cffff4444[Test]|r Simulated Void Marked FADE on " .. playerName)
    else
        -- Toggle
        if RAPE.VoidMarked[playerName] and RAPE.VoidMarked[playerName][testInstanceID] then
            RAPE.VoidMarked[playerName][testInstanceID] = nil
            if next(RAPE.VoidMarked[playerName]) == nil then
                RAPE.VoidMarked[playerName] = nil
            end
            BroadcastVoidMark("FADE:" .. testInstanceID)
            RAPE.Print("|cffff4444[Test]|r Simulated Void Marked FADE on " .. playerName)
        else
            RAPE.VoidMarked[playerName] = RAPE.VoidMarked[playerName] or {}
            RAPE.VoidMarked[playerName][testInstanceID] = {
                gainTime = GetTime(),
                class    = playerClass or "UNKNOWN",
            }
            BroadcastVoidMark("GAIN:" .. testInstanceID)
            RAPE.Print("|cffff4444[Test]|r Simulated Void Marked GAIN on " .. playerName)
        end
    end

    if RAPE.VoidMarkedFrame and RAPE.VoidMarkedFrame.Refresh then
        RAPE.VoidMarkedFrame.Refresh()
    end
end
