-- MonkeyTracker: Init.lua
-- MUST be the first file in the load order.
-- Creates the global addon namespace so all subsequent modules can reference it.

RAPE = RAPE or {}

RAPE.VERSION  = "1.0.0"
RAPE.NAME     = "RAPE"

-- Runtime state (initialized here so modules can safely reference these keys)
RAPE.inCombat  = false
RAPE.Roster    = {}       -- [playerName] = class
RAPE.ActiveCDs = {}       -- [playerName][spellID] = entry
RAPE.PlayerSpells = {}    -- [playerName][spellID] = cooldown (only spells they have talented)
RAPE.VoidMarked = {}  -- [playerName] = { gainTime, class }
RAPE.ActiveBars = {}
RAPE.BarPool   = {}

-- Admin / version check state
RAPE.VersionResponses      = {}   -- [playerName] = versionString
RAPE.VersionCheckInProgress = false
RAPE.VersionCheckTime       = 0
