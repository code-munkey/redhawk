-- MonkeyTracker: SpellDB.lua
-- Database of all tracked healing and utility cooldowns.
-- To add a new spell: add an entry with the spellID as the key.
-- NOTE: Spell IDs are based on retail/TWW. Verify against Midnight patch notes
--       if any were changed or replaced in 12.x.

-- Categories for filtering/display
RAPE.CATEGORY = {
    HEALING   = "Healing",
    DEFENSIVE = "Defensive",
    UTILITY   = "Utility",
}

-- Class tokens used as filter keys
-- (matches WoW's internals: "DRUID", "PALADIN", etc.)

--[[
    SpellDB entry format:
    [spellID] = {
        name     = string,   -- display name (fallback if API unavailable)
        class    = string,   -- WoW class token in CAPS
        cooldown = number,   -- base cooldown in seconds
        category = string,   -- RAPE.CATEGORY value
        charges  = number,   -- number of charges (default 1)
        note     = string,   -- optional tooltip note
    }
--]]

RAPE.SpellDB = {
    [31821] = {
        name     = "Aura Mastery",
        class    = "PALADIN",
        cooldown = 180,
        category = RAPE.CATEGORY.DEFENSIVE,
    },
    [98008] = {
        name     = "Spirit Link Totem",
        class    = "SHAMAN",
        cooldown = 180,
        category = RAPE.CATEGORY.HEALING
    },
    [62618] = {
        name     = "Power Word: Barrier",
        class    = "PRIEST",
        cooldown = 180,
        category = RAPE.CATEGORY.DEFENSIVE
    },
    [115310] = {
        name     = "Revival",
        class    = "MONK",
        cooldown = 180,
        category = RAPE.CATEGORY.HEALING
    },
    [374227] = {
        name     = "Zephyr",
        class    = "EVOKER",
        cooldown = 120,
        category = RAPE.CATEGORY.DEFENSIVE,
    },
    [196718] = {
        name     = "Darkness",
        class    = "DEMONHUNTER",
        cooldown = 300,
        category = RAPE.CATEGORY.DEFENSIVE
    },
    [97462] = {
        name     = "Rallying Cry",
        class    = "WARRIOR",
        cooldown = 180,
        category = RAPE.CATEGORY.DEFENSIVE,
    },
    [33206] = {
        name     = "Pain Suppression",
        class    = "PRIEST",
        cooldown = 180,
        category = RAPE.CATEGORY.DEFENSIVE
    },
    [102342] = {
        name     = "Ironbark",
        class    = "DRUID",
        cooldown = 90,
        category = RAPE.CATEGORY.DEFENSIVE
    },
    [6940] = {
        name     = "Blessing of Sacrifice",
        class    = "PALADIN",
        cooldown = 120,
        category = RAPE.CATEGORY.DEFENSIVE
    },
    [357170] = {
        name     = "Time Dilation",
        class    = "EVOKER",
        cooldown = 60,
        category = RAPE.CATEGORY.DEFENSIVE
    },
    [77761] = {
        name     = "Stampeding Roar",
        class    = "DRUID",
        cooldown = 120,
        category = RAPE.CATEGORY.UTILITY,
    },
    [192077] = {
        name     = "Windrush Totem",
        class    = "SHAMAN",
        cooldown = 120,
        category = RAPE.CATEGORY.UTILITY,
    },
    [51052] = {
        name     = "Anti-Magic Zone",
        class    = "DEATHKNIGHT",
        cooldown = 120,
        category = RAPE.CATEGORY.UTILITY
    }
}

-- Remove spells with cooldown = 0 (non-tracked passives that slipped in)
for id, data in pairs(RAPE.SpellDB) do
    if data.cooldown == 0 then
        RAPE.SpellDB[id] = nil
    end
end

-- Build a reverse lookup: spellID -> true for fast CLEU filtering
RAPE.TrackedSpellIDs = {}
for id in pairs(RAPE.SpellDB) do
    RAPE.TrackedSpellIDs[id] = true
end
