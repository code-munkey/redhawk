-- MonkeyTracker: Options.lua
-- DB defaults, InitDB, and slash commands. (UI fully moved to OptionsPanel.lua)

RAPE.Options = {}
local O = RAPE.Options

-- ============================================================
-- Default Settings
-- ============================================================

RAPE.DB_DEFAULTS = {
    debugMode         = false,
    disabledSpells    = {},
    categoryFilter    = {
        [RAPE.CATEGORY.HEALING]   = true,
        [RAPE.CATEGORY.DEFENSIVE] = true,
        [RAPE.CATEGORY.UTILITY]   = true,
    },
    cooldownOverrides = {},
    windows           = {},   -- populated by WM.DefaultWindowConfig on first run
    barHeight         = 28,
    barFont           = "Fonts\\FRIZQT__.TTF",
    barFontSize       = 11,
    piAssistanceMode  = 3,    -- 1=List, 2=Highlight, 3=Both
    piTrackedPlayers  = {},
    NullCoronaTracker = true,  -- feature flag: track Null Corona healing absorb
}

--- Merge saved variables with defaults and handle legacy migration.
function RAPE.InitDB()
    if not RapeDB then RapeDB = {} end

    for k, v in pairs(RAPE.DB_DEFAULTS) do
        if RapeDB[k] == nil then
            if type(v) == "table" then
                local copy = {}
                for k2, v2 in pairs(v) do copy[k2] = v2 end
                RapeDB[k] = copy
            else
                RapeDB[k] = v
            end
        end
    end

    local db = RapeDB

    -- MIGRATION: old single-window fields → windows[1]
    if (db.x or db.y or db.width or db.height) and (#db.windows == 0) then
        db.windows[1] = {
            label  = "Window 1",
            x      = db.x,
            y      = db.y,
            w      = db.width  or 320,
            h      = db.height or 200,
            locked = db.locked or false,
            hidden = db.hidden or false,
            spells = {},
        }
        db.x = nil; db.y = nil; db.width = nil; db.height = nil
        db.locked = nil; db.hidden = nil
    end

    -- Ensure at least one window config
    if not db.windows or #db.windows == 0 then
        db.windows = { RAPE.WM.DefaultWindowConfig(1) }
    end

    RAPE.db = RapeDB
end

-- ============================================================
-- Slash Commands
-- ============================================================

function O.RegisterSlashCommands()
    SLASH_RAPE1 = "/RAPE"

    SlashCmdList["RAPE"] = function(msg)
        msg = msg and strtrim(msg:lower()) or ""

        if msg == "" or msg == "show" then
            RAPE.MainFrame.Show()
            RAPE.Print("Tracker shown. Type /RAPE hide to hide.")

        elseif msg == "hide" then
            RAPE.MainFrame.Hide()
            RAPE.Print("Tracker hidden. Type /RAPE show to show.")

        elseif msg == "options" or msg == "config" or msg == "admin" then
            if RAPE.MainPanel then RAPE.MainPanel:Toggle() end
        elseif msg == "lock" then
            RAPE.db.windows[1].locked = true
            RAPE.WM.ApplyLockState(1)
            RAPE.Print("Window 1 locked.")
        elseif msg == "unlock" then
            RAPE.db.windows[1].locked = false
            RAPE.WM.ApplyLockState(1)
            RAPE.Print("Window 1 unlocked.")
        elseif msg == "reset" then
            RAPE.ClearAllCooldowns()
            RAPE.Print("All cooldowns cleared.")
        elseif msg == "debug" then
            RAPE.db.debugMode = not RAPE.db.debugMode
            RAPE.Print("Debug mode:", RAPE.db.debugMode and "ON" or "OFF")
        elseif msg == "version" then
            RAPE.BroadcastVersionCheck()
        elseif msg == "reqspells" then
            RAPE.RequestSpellLists()
        elseif msg:sub(1, 8) == "refresh " then
            RAPE.RequestPlayerRefresh(strtrim(msg:sub(9)))
        elseif msg == "voidmark" then
            if RAPE.VoidMarkedFrame then
                RAPE.VoidMarkedFrame.Toggle()
            end
        elseif msg == "testvoidmark" or msg:sub(1, 13) == "testvoidmark " then
            local action = strtrim(msg:sub(14))
            RAPE.TestVoidMark(action)

        elseif msg == "nullcorona" then
            if RAPE.NullCoronaFrame then
                RAPE.NullCoronaFrame.Toggle()
            end
        elseif msg:sub(1, 15) == "testnullcorona " then
            local args = strtrim(msg:sub(16))
            local action, target, amt = strsplit(" ", args, 3)
            RAPE.TestNullCorona(action, target ~= "" and target or nil, tonumber(amt))

        elseif msg == "debug roster" then
            RAPE.Print("Current roster (" .. RAPE.TableCount(RAPE.Roster) .. " members):")
            for name, class in pairs(RAPE.Roster) do
                RAPE.Print("  " .. name .. " — " .. class)
            end

        elseif msg == "debug cds" then
            local list = RAPE.GetActiveCooldowns()
            if #list == 0 then
                RAPE.Print("No active cooldowns tracked.")
            else
                RAPE.Print("Active cooldowns (" .. #list .. "):")
                for _, e in ipairs(list) do
                    RAPE.Print(string.format("  [%s] %s — %s remaining",
                        e.playerName, e.spellData.name, RAPE.FormatTime(e.remaining)))
                end
            end

        elseif msg == "help" then
            RAPE.Print("/RAPE              — show tracker")
            RAPE.Print("/RAPE hide         — hide tracker")
            RAPE.Print("/RAPE toggle       — toggle visibility")
            RAPE.Print("/RAPE lock/unlock  — lock/unlock window 1")
            RAPE.Print("/RAPE reset        — clear all active cooldowns")
            RAPE.Print("/RAPE config/admin — open settings panel")
            RAPE.Print("/RAPE debug        — toggle debug logging")
            RAPE.Print("/RAPE version      — broadcast version check")
            RAPE.Print("/RAPE reqspells    — request spell lists from all")
            RAPE.Print("/RAPE refresh <name> — request refresh from player")
            RAPE.Print("/RAPE voidmark      — toggle Void Marked tracker")
            RAPE.Print("/RAPE testvoidmark [gain|fade] — simulate void mark")
            RAPE.Print("/RAPE nullcorona    — toggle Null Corona tracker")
            RAPE.Print("/RAPE testnullcorona <add|absorb|remove> [name] [amount]")
            RAPE.Print("/RAPE debug roster — print known raid members")
            RAPE.Print("/RAPE debug cds    — list all active cooldowns")

        else
            RAPE.Print("Unknown command. Type /RAPE help for options.")
        end
    end
end
