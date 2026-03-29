-- MonkeyTracker: PIAssistance.lua
-- Handles tracking active DPS cooldown burst windows for targeted players,
-- and optionally applying a glow to their standard Blizzard raid frame.

RAPE.PI = {}
local PI = RAPE.PI

local updateFrame = CreateFrame("Frame")
local CHECK_INTERVAL = 0.5
local timeSinceLastCheck = 0

PI.ActivePlayers = {} -- [playerName] = true

--- Toggle Blizzard Raid Frame glow for a targeted player
local function UpdateGlows(playerName, active)
    if not CompactRaidFrameContainer then return end
    
    for i = 1, 40 do
        local frame = _G["CompactRaidFrame" .. i]
        if frame and frame.unit then
            -- Note: UnitName returns the localized name without realm if on same realm.
            -- The player name keys we use might be string.split("-", name).
            local frameName = strsplit("-", UnitName(frame.unit) or "")
            if frameName == playerName then
                if active then
                    ActionButton_ShowOverlayGlow(frame)
                else
                    ActionButton_HideOverlayGlow(frame)
                end
            end
        end
    end
end

--- Scans all tracked players for an active DPS cooldown
function PI.CheckActiveDPSCDs()
    local mode = RAPE.db and RAPE.db.piAssistanceMode or 3
    local now = GetTime()
    local currentlyActive = {}

    if RAPE.db and RAPE.db.piTrackedPlayers then
        for playerName, tracked in pairs(RAPE.db.piTrackedPlayers) do
            if tracked and RAPE.ActiveCDs[playerName] then
                for spellID, cdData in pairs(RAPE.ActiveCDs[playerName]) do
                    local spellInfo = RAPE.SpellDB[spellID]
                    if spellInfo and spellInfo.category == RAPE.CATEGORY.DPS and spellInfo.duration then
                        -- Check if the burst window is still active
                        if cdData.castTime + spellInfo.duration > now then
                            currentlyActive[playerName] = { 
                                spellID = spellID, 
                                remaining = (cdData.castTime + spellInfo.duration) - now 
                            }
                            break
                        end
                    end
                end
            end
        end
    end

    local changed = false

    -- Check for new or continuing activations
    for playerName, info in pairs(currentlyActive) do
        if not PI.ActivePlayers[playerName] then
            PI.ActivePlayers[playerName] = info
            changed = true
            if mode == 2 or mode == 3 then
                UpdateGlows(playerName, true)
            end
        end
    end

    -- Check for expirations
    for playerName in pairs(PI.ActivePlayers) do
        if not currentlyActive[playerName] then
            PI.ActivePlayers[playerName] = nil
            changed = true
            UpdateGlows(playerName, false)
        end
    end

    -- If list UI wants frequent updates (e.g. for progression bars) we might want 
    -- to refresh even if count hasn't changed. We'll refresh if frame is shown.
    if RAPE.PIFrame and RAPE.PIFrame.frame:IsShown() then
        RAPE.PIFrame.Refresh()
    elseif changed and RAPE.PIFrame and RAPE.PIFrame.Refresh then
        RAPE.PIFrame.Refresh()
    end
end

updateFrame:SetScript("OnUpdate", function(self, elapsed)
    if not RAPE.db then return end
    
    timeSinceLastCheck = timeSinceLastCheck + elapsed
    if timeSinceLastCheck >= CHECK_INTERVAL then
        timeSinceLastCheck = 0
        PI.CheckActiveDPSCDs()
    end
end)

function PI.ClearGlows()
    for playerName in pairs(PI.ActivePlayers) do
        UpdateGlows(playerName, false)
    end
    PI.ActivePlayers = {}
    if RAPE.PIFrame and RAPE.PIFrame.Refresh then
        RAPE.PIFrame.Refresh()
    end
end
