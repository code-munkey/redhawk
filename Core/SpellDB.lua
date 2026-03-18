-- MonkeyTracker: SpellDB.lua
-- Database of all tracked healing and utility cooldowns.
-- To add a new spell: add an entry with the spellID as the key.
-- NOTE: Spell IDs are based on retail/TWW. Verify against Midnight patch notes
--       if any were changed or replaced in 12.x.

local MT = MonkeyTracker

-- Categories for filtering/display
MT.CATEGORY = {
    HEALING  = "Healing",
    UTILITY  = "Utility",
    EXTERNAL = "External",
}

-- Class tokens used as filter keys
-- (matches WoW's internals: "DRUID", "PALADIN", etc.)

--[[
    SpellDB entry format:
    [spellID] = {
        name     = string,   -- display name (fallback if API unavailable)
        class    = string,   -- WoW class token in CAPS
        cooldown = number,   -- base cooldown in seconds
        category = string,   -- MT.CATEGORY value
        charges  = number,   -- number of charges (default 1)
        note     = string,   -- optional tooltip note
    }
--]]

MT.SpellDB = {

    -- =========================================================
    -- DRUID
    -- =========================================================
    [740] = {
        name     = "Tranquility",
        class    = "DRUID",
        cooldown = 180,
        category = MT.CATEGORY.HEALING,
    },
    [77761] = {
        name     = "Stampeding Roar",
        class    = "DRUID",
        cooldown = 120,
        category = MT.CATEGORY.UTILITY,
        note     = "Increases movement speed of all nearby allies.",
    },
    [29166] = {
        name     = "Innervate",
        class    = "DRUID",
        cooldown = 180,
        category = MT.CATEGORY.EXTERNAL,
        note     = "Cast on target to restore mana.",
    },
    [20484] = {
        name     = "Rebirth",
        class    = "DRUID",
        cooldown = 600,
        category = MT.CATEGORY.UTILITY,
        note     = "Combat resurrection.",
    },
    [22812] = {
        name     = "Barkskin",
        class    = "DRUID",
        cooldown = 34,
        category = MT.CATEGORY.UTILITY,
        note     = "",
    },

    -- =========================================================
    -- PALADIN
    -- =========================================================
    [31821] = {
        name     = "Aura Mastery",
        class    = "PALADIN",
        cooldown = 180,
        category = MT.CATEGORY.HEALING,
        note     = "Doubles the effect of current aura.",
    },
    [6940] = {
        name     = "Blessing of Sacrifice",
        class    = "PALADIN",
        cooldown = 120,
        category = MT.CATEGORY.EXTERNAL,
        note     = "Transfers 30% of damage taken by target to the Paladin.",
    },
    [1022] = {
        name     = "Blessing of Protection",
        class    = "PALADIN",
        cooldown = 300,
        category = MT.CATEGORY.EXTERNAL,
        note     = "Protects target from physical damage.",
    },
    [64901] = {
        name     = "Symbol of Hope",
        class    = "PALADIN",
        cooldown = 180,
        category = MT.CATEGORY.HEALING,
        note     = "Restores mana to all nearby healer specializations.",
    },
    [498] = {
        name     = "Divine Protection",
        class    = "PALADIN",
        cooldown = 60,
        category = MT.CATEGORY.UTILITY,
    },

    -- =========================================================
    -- PRIEST
    -- =========================================================
    [64843] = {
        name     = "Divine Hymn",
        class    = "PRIEST",
        cooldown = 180,
        category = MT.CATEGORY.HEALING,
    },
    [62618] = {
        name     = "Power Word: Barrier",
        class    = "PRIEST",
        cooldown = 180,
        category = MT.CATEGORY.HEALING,
        note     = "Summons a barrier to protect allies.",
    },
    [33206] = {
        name     = "Pain Suppression",
        class    = "PRIEST",
        cooldown = 180,
        category = MT.CATEGORY.EXTERNAL,
        note     = "Reduces target's damage taken by 40%.",
    },
    [271466] = {
        name     = "Luminous Barrier",
        class    = "PRIEST",
        cooldown = 180,
        category = MT.CATEGORY.HEALING,
        note     = "Holy variant of Power Word: Barrier.",
    },
    [15286] = {
        name     = "Vampiric Embrace",
        class    = "PRIEST",
        cooldown = 0,   -- no CD, tracked as an aura; skip if 0 in logic
        category = MT.CATEGORY.HEALING,
    },
    [47788] = {
        name     = "Guardian Spirit",
        class    = "PRIEST",
        cooldown = 180,
        category = MT.CATEGORY.EXTERNAL,
        note     = "Prevents target from dying once.",
    },

    -- =========================================================
    -- SHAMAN
    -- =========================================================
    [108280] = {
        name     = "Healing Tide Totem",
        class    = "SHAMAN",
        cooldown = 180,
        category = MT.CATEGORY.HEALING,
    },
    [98008] = {
        name     = "Spirit Link Totem",
        class    = "SHAMAN",
        cooldown = 180,
        category = MT.CATEGORY.HEALING,
        note     = "Equalizes HP among nearby allies.",
    },
    [192077] = {
        name     = "Wind Rush Totem",
        class    = "SHAMAN",
        cooldown = 120,
        category = MT.CATEGORY.UTILITY,
        note     = "Grants movement speed to nearby allies.",
    },
    [207399] = {
        name     = "Ancestral Protection Totem",
        class    = "SHAMAN",
        cooldown = 300,
        category = MT.CATEGORY.UTILITY,
        note     = "Prevents death once for nearby allies.",
    },
    [16190] = {
        name     = "Mana Tide Totem",
        class    = "SHAMAN",
        cooldown = 180,
        category = MT.CATEGORY.HEALING,
        note     = "Restores mana to nearby allies.",
    },

    -- =========================================================
    -- MONK
    -- =========================================================
    [115310] = {
        name     = "Revival",
        class    = "MONK",
        cooldown = 180,
        category = MT.CATEGORY.HEALING,
        note     = "Heals all allies and removes debuffs.",
    },
    [116849] = {
        name     = "Life Cocoon",
        class    = "MONK",
        cooldown = 120,
        category = MT.CATEGORY.EXTERNAL,
        note     = "Encases target in a healing cocoon.",
    },
    [322118] = {
        name     = "Invoke Yu'lon",
        class    = "MONK",
        cooldown = 180,
        category = MT.CATEGORY.HEALING,
    },
    [325197] = {
        name     = "Invoke Chi-Ji",
        class    = "MONK",
        cooldown = 180,
        category = MT.CATEGORY.HEALING,
    },

    -- =========================================================
    -- EVOKER (Preservation)
    -- =========================================================
    [363534] = {
        name     = "Rewind",
        class    = "EVOKER",
        cooldown = 240,
        category = MT.CATEGORY.HEALING,
        note     = "Rewinds time, healing nearby allies.",
    },
    [374348] = {
        name     = "Zephyr",
        class    = "EVOKER",
        cooldown = 120,
        category = MT.CATEGORY.UTILITY,
        note     = "Increases movement speed and reduces damage taken.",
    },
    [357170] = {
        name     = "Time Spiral",
        class    = "EVOKER",
        cooldown = 120,
        category = MT.CATEGORY.UTILITY,
    },
    [370537] = {
        name     = "Rescue",
        class    = "EVOKER",
        cooldown = 60,
        category = MT.CATEGORY.EXTERNAL,
        note     = "Lifts and carries an ally to safety.",
    },

    -- =========================================================
    -- DEATH KNIGHT
    -- =========================================================
    [51052] = {
        name     = "Anti-Magic Zone",
        class    = "DEATHKNIGHT",
        cooldown = 120,
        category = MT.CATEGORY.UTILITY,
        note     = "Dome that reduces magic damage for allies.",
    },
    [49576] = {
        name     = "Death Grip",
        class    = "DEATHKNIGHT",
        cooldown = 25,
        category = MT.CATEGORY.UTILITY,
    },
    [48792] = {
        name     = "Icebound Fortitude",
        class    = "DEATHKNIGHT",
        cooldown = 180,
        category = MT.CATEGORY.UTILITY,
    },

    -- =========================================================
    -- DEMON HUNTER
    -- =========================================================
    [196718] = {
        name     = "Darkness",
        class    = "DEMONHUNTER",
        cooldown = 300,
        category = MT.CATEGORY.UTILITY,
        note     = "Creates a cloud granting a chance to avoid damage.",
    },

    -- =========================================================
    -- WARRIOR
    -- =========================================================
    [97462] = {
        name     = "Rallying Cry",
        class    = "WARRIOR",
        cooldown = 180,
        category = MT.CATEGORY.UTILITY,
        note     = "Temporarily increases HP of all nearby allies.",
    },

    -- =========================================================
    -- HUNTER
    -- =========================================================
    [264735] = {
        name     = "Survival of the Fittest",
        class    = "HUNTER",
        cooldown = 180,
        category = MT.CATEGORY.UTILITY,
        note     = "Reduces damage taken for Hunter and pet.",
    },
    [53480] = {
        name     = "Roar of Sacrifice",
        class    = "HUNTER",
        cooldown = 60,
        category = MT.CATEGORY.EXTERNAL,
        note     = "Pet takes 20% of damage from target ally.",
    },

    -- =========================================================
    -- MAGE
    -- =========================================================
    [295238] = {
        name     = "Blazing Barrier",
        class    = "MAGE",
        cooldown = 25,
        category = MT.CATEGORY.UTILITY,
        note     = "",
    },

    -- =========================================================
    -- ROGUE
    -- =========================================================
    [212182] = {
        name     = "Smoke Bomb",
        class    = "ROGUE",
        cooldown = 180,
        category = MT.CATEGORY.UTILITY,
        note     = "Creates a smoke cloud, reducing enemy AoE damage.",
    },
    [114018] = {
        name     = "Shroud of Concealment",
        class    = "ROGUE",
        cooldown = 360,
        category = MT.CATEGORY.UTILITY,
        note     = "Shrouds nearby allies, allowing them to sneak.",
    },

    -- =========================================================
    -- WARLOCK
    -- =========================================================
    [20707] = {
        name     = "Soulstone",
        class    = "WARLOCK",
        cooldown = 600,
        category = MT.CATEGORY.UTILITY,
        note     = "Combat resurrection via Soulstone.",
    },
    [108416] = {
        name     = "Dark Pact",
        class    = "WARLOCK",
        cooldown = 60,
        category = MT.CATEGORY.UTILITY,
    },
}

-- Remove spells with cooldown = 0 (non-tracked passives that slipped in)
for id, data in pairs(MT.SpellDB) do
    if data.cooldown == 0 then
        MT.SpellDB[id] = nil
    end
end

-- Build a reverse lookup: spellID -> true for fast CLEU filtering
MT.TrackedSpellIDs = {}
for id in pairs(MT.SpellDB) do
    MT.TrackedSpellIDs[id] = true
end
