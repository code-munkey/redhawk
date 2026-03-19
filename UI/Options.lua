-- MonkeyTracker: Options.lua
-- Settings panel using the Blizzard Settings API (introduced in Dragonflight, still active in Midnight).
-- Fallback chat commands are always registered regardless of Settings API availability.

local MT = MonkeyTracker

MT.Options = {}
local O = MT.Options

-- ============================================================
-- Default Settings
-- ============================================================

MT.DB_DEFAULTS = {
    locked         = false,
    hidden         = false,
    debugMode      = false,
    x              = nil,
    y              = nil,
    width          = 320,
    height         = 200,
    disabledSpells = {},  -- [spellID] = true → suppress that CD
    categoryFilter = {
        [MT.CATEGORY.HEALING]   = true,
        [MT.CATEGORY.DEFENSIVE] = true,
        [MT.CATEGORY.UTILITY]   = true,
    },
    cooldownOverrides = {}, -- [spellID] = number → custom cooldown
}

--- Merge saved variables with defaults (non-destructively).
function MT.InitDB()
    if not MonkeyTrackerDB then
        MonkeyTrackerDB = {}
    end

    -- Shallow merge: copy missing defaults into saved table
    for k, v in pairs(MT.DB_DEFAULTS) do
        if MonkeyTrackerDB[k] == nil then
            -- Deep copy tables to avoid shared references
            if type(v) == "table" then
                local copy = {}
                for k2, v2 in pairs(v) do copy[k2] = v2 end
                MonkeyTrackerDB[k] = copy
            else
                MonkeyTrackerDB[k] = v
            end
        end
    end

    MT.db = MonkeyTrackerDB
end

-- ============================================================
-- Blizzard Settings API Registration
-- ============================================================

function O.RegisterSettingsPanel()
    -- Guard: Settings namespace may not exist in all builds
    if not Settings or not Settings.RegisterAddOnCategory then
        MT.Debug("Blizzard Settings API not available, using slash commands only.")
        return
    end

    local category = Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(
        CreateFrame("Frame"),
        "MonkeyTracker"
    ))

    -- In Midnight, Settings.RegisterAddOnSetting does not accept function callbacks.
    -- For now, we rely on the extensive Slash Commands (/mt) for config,
    -- but we register the category so it appears in the AddOns list.
    -- The canvas could be populated with standard UI widgets later if needed.

    O.category = category
end

function O.Toggle()
    if O.category then
        Settings.OpenToCategory(O.category:GetID())
    else
        MT.Print("Open the Game Menu → Interface → AddOns → MonkeyTracker")
    end
end

-- ============================================================
-- Slash Commands
-- ============================================================

function O.RegisterSlashCommands()
    SLASH_MONKEYTRACKER1 = "/mt"
    SLASH_MONKEYTRACKER2 = "/monkeytracker"

    SlashCmdList["MONKEYTRACKER"] = function(msg)
        msg = msg and strtrim(msg:lower()) or ""

        if msg == "" or msg == "show" then
            MT.MainFrame.Show()
            MT.Print("Tracker shown. Type /mt hide to hide.")

        elseif msg == "hide" then
            MT.MainFrame.Hide()
            MT.Print("Tracker hidden. Type /mt show to show.")

        elseif msg == "toggle" then
            MT.MainFrame.Toggle()

        elseif msg == "lock" then
            MT.db.locked = true
            MT.MainFrame.ApplyLockState()
            MT.Print("Frame locked.")

        elseif msg == "unlock" then
            MT.db.locked = false
            MT.MainFrame.ApplyLockState()
            MT.Print("Frame unlocked.")

        elseif msg == "reset" then
            MT.ClearAllCooldowns()
            MT.Print("All cooldowns cleared.")

        elseif msg == "config" then
            O.Toggle()

        elseif msg == "debug" then
            MT.db.debugMode = not MT.db.debugMode
            MT.Print("Debug mode:", MT.db.debugMode and "ON" or "OFF")

        elseif msg == "debug roster" then
            MT.Print("Current roster (" .. MT.TableCount(MT.Roster) .. " members):")
            for name, class in pairs(MT.Roster) do
                MT.Print("  " .. name .. " — " .. class)
            end

        elseif msg == "debug cds" then
            local list = MT.GetActiveCooldowns()
            if #list == 0 then
                MT.Print("No active cooldowns tracked.")
            else
                MT.Print("Active cooldowns (" .. #list .. "):")
                for _, e in ipairs(list) do
                    MT.Print(string.format("  [%s] %s — %s remaining",
                        e.playerName, e.spellData.name, MT.FormatTime(e.remaining)))
                end
            end

        elseif msg == "help" then
            MT.Print("/mt            — show tracker")
            MT.Print("/mt hide       — hide tracker")
            MT.Print("/mt toggle     — toggle visibility")
            MT.Print("/mt lock/unlock— lock/unlock frame position")
            MT.Print("/mt reset      — clear all active cooldowns")
            MT.Print("/mt config     — open settings panel")
            MT.Print("/mt debug      — toggle debug mode")
            MT.Print("/mt debug roster — print known raid members")
            MT.Print("/mt debug cds    — list all active cooldowns")

        else
            MT.Print("Unknown command. Type /mt help for options.")
        end
    end
end
