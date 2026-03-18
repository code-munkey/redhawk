-- MonkeyTracker: MonkeyTracker.lua
-- Entry point. Bootstraps all modules on ADDON_LOADED / PLAYER_LOGIN.
-- The global namespace is created by Core/Init.lua (loaded first).

local MT = MonkeyTracker

-- ============================================================
-- Bootstrap: called from EventHandler on ADDON_LOADED
-- ============================================================

function MT.OnAddonLoaded()
    -- 1. Initialize saved variables / defaults
    MT.InitDB()

    -- 2. Register slash commands
    MT.Options.RegisterSlashCommands()

    -- 3. Build the main display frame
    MT.MainFrame.Build()

    -- 4. Try to register the Blizzard settings panel
    --    (safe to call even if Settings API is not available)
    MT.Options.RegisterSettingsPanel()

    MT.Debug("Addon loaded. Version:", MT.VERSION)
end

-- ============================================================
-- Bootstrap: called from EventHandler on PLAYER_LOGIN
-- (fires after saved variables are loaded and UI is ready)
-- ============================================================

function MT.OnPlayerLogin()
    -- Initial roster scan so we have class info before any combat
    MT.OnRosterUpdate()

    MT.Print(string.format("v%s loaded. Type |cffffd700/mt help|r for commands.", MT.VERSION))
end
