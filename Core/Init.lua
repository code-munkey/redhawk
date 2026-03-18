-- MonkeyTracker: Init.lua
-- MUST be the first file in the load order.
-- Creates the global addon namespace so all subsequent modules can reference it.

MonkeyTracker = MonkeyTracker or {}

local MT = MonkeyTracker

MT.VERSION  = "1.0.0"
MT.NAME     = "MonkeyTracker"

-- Runtime state (initialized here so modules can safely reference these keys)
MT.inCombat  = false
MT.Roster    = {}       -- [playerName] = class  (populated by CooldownTracker)
MT.ActiveCDs = {}       -- [playerName][spellID] = entry
MT.ActiveBars = {}      -- currently displayed bar widgets
MT.BarPool   = {}       -- recycled bar widgets
