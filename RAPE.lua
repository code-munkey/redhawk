-- MonkeyTracker: MonkeyTracker.lua
-- Entry point. Bootstraps all modules on ADDON_LOADED / PLAYER_LOGIN.
-- The global namespace is created by Core/Init.lua (loaded first).

-- ============================================================
-- Bootstrap: called from EventHandler on ADDON_LOADED
-- ============================================================

function RAPE.OnAddonLoaded()
    -- 1. Initialize saved variables / defaults
    RAPE.InitDB()

    -- 2. Register slash commands
    RAPE.Options.RegisterSlashCommands()

    -- 3. Build the new LanternUX display frame and traditional main frame
    RAPE.MainFrame.Build()
    if RAPE.BuildMainPanel then
        RAPE.BuildMainPanel()
    end
    if RAPE.VoidMarkedFrame and RAPE.VoidMarkedFrame.Build then
        RAPE.VoidMarkedFrame.Build()
    end
    if RAPE.PIFrame and RAPE.PIFrame.Build then
        RAPE.PIFrame.Build()
    end

    -- 5. Build the Admin panel has been replaced by LanternUX MainPanel

    RAPE.Debug("Addon loaded. Version:", RAPE.VERSION)
end

-- ============================================================
-- Bootstrap: called from EventHandler on PLAYER_LOGIN
-- (fires after saved variables are loaded and UI is ready)
-- ============================================================

function RAPE.OnPlayerLogin()
    -- Initial roster scan so we have class info before any combat
    RAPE.OnRosterUpdate()

    RAPE.Print(string.format("v%s loaded. Type |cffffd700/RAPE help|r for commands.", RAPE.VERSION))
end
