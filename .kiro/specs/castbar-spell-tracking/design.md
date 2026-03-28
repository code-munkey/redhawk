# Design Document: castbar-spell-tracking

## Overview

This change replaces the `COMBAT_LOG_EVENT_UNFILTERED` spell detection mechanism in `Core/EventHandler.lua` with `UNIT_SPELLCAST_SUCCEEDED`, available in WoW: Midnight. The public combat log is being removed in Midnight; `UNIT_SPELLCAST_SUCCEEDED` fires per unit token and carries `unitTarget`, `castGUID` (the castBarId), and `spellID` directly on the event payload — eliminating the need to parse `CombatLogGetCurrentEventInfo()`.

All downstream modules (CooldownTracker, SpellDB, UI) are untouched. The only file modified is `Core/EventHandler.lua`.

## Architecture

The change is a drop-in replacement within the existing event dispatch table. The overall addon architecture is unchanged:

```
UNIT_SPELLCAST_SUCCEEDED (WoW client, per unit token)
        │
        ▼
EventHandler.lua  ──── filter: Roster + TrackedSpellIDs + dedup cache
        │
        ▼
RAPE.OnSpellCast(playerName, playerClass, spellID)
        │
        ▼
CooldownTracker  ──►  UI
```

The deduplication cache is a new module-local table in EventHandler.lua, cleared on `PLAYER_ENTERING_WORLD`.

## Components and Interfaces

### EventHandler.lua changes

**Remove:**
- `SafeReg("COMBAT_LOG_EVENT_UNFILTERED")` from the `ADDON_LOADED` block
- The `OnCombatLogEvent()` function and its dispatch branch

**Add:**
- `local seenCasts = {}` — module-local deduplication cache
- A loop in the `ADDON_LOADED` block registering `UNIT_SPELLCAST_SUCCEEDED` for each unit token: `"player"`, `"party1"`–`"party5"`, and `"raid1"`–`"raid40"` (with fallback warning if any registration fails)
- `OnUnitSpellCastSucceeded(event, unitTarget, castGUID, spellID)` handler function
- Dispatch branch for `UNIT_SPELLCAST_SUCCEEDED` and cache-clear branch for `PLAYER_ENTERING_WORLD`

### Handler logic (OnUnitSpellCastSucceeded)

```lua
local function OnUnitSpellCastSucceeded(event, unitTarget, castGUID, spellID)
    -- 1. Deduplication (castGUID == castBarId)
    if seenCasts[castGUID] then return end

    -- 2. Spell filter
    if not spellID or not RAPE.TrackedSpellIDs[spellID] then return end

    -- 3. Resolve name
    local fullName = UnitName(unitTarget)
    if not fullName or fullName == UNKNOWNOBJECT then return end
    local shortName = strsplit("-", fullName)

    -- 4. Roster filter
    local playerClass = RAPE.Roster[shortName]
    if not playerClass then return end

    -- 5. Record + dispatch
    seenCasts[castGUID] = true
    RAPE.Debug("UNIT_SPELLCAST_SUCCEEDED:", shortName, spellID)
    RAPE.OnSpellCast(shortName, playerClass, spellID)
end
```

### Registration (ADDON_LOADED block)

```lua
local units = {"player"}
for i = 1, 5  do units[#units+1] = "party"..i end
for i = 1, 40 do units[#units+1] = "raid"..i  end
for _, unit in ipairs(units) do
    SafeReg("UNIT_SPELLCAST_SUCCEEDED", unit)
end
```

### Interfaces (unchanged)

- `RAPE.OnSpellCast(playerName, playerClass, spellID)` — signature unchanged
- `RAPE.TrackedSpellIDs[spellID]` — O(1) lookup, unchanged
- `RAPE.Roster[playerName]` — maps short name → class token, unchanged

## Data Models

### seenCasts (new)

```lua
-- module-local, lives in EventHandler.lua
local seenCasts = {}  -- { [castBarId: string] = true }
```

Cleared on `PLAYER_ENTERING_WORLD` to prevent unbounded growth across zone transitions:

```lua
seenCasts = {}
```

No persistence — session-scoped only. No serialization needed.

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Non-roster and untracked events are silently ignored

*For any* `UNIT_SPELLCAST_SUCCEEDED` event where either the resolved player name is absent from `RAPE.Roster` OR the `spellID` is absent from `RAPE.TrackedSpellIDs`, `RAPE.OnSpellCast` shall never be called.

**Validates: Requirements 1.4, 1.5**

### Property 2: Valid cast dispatches correct arguments

*For any* `UNIT_SPELLCAST_SUCCEEDED` event where the unit resolves to a Roster member and the spellID is in `TrackedSpellIDs`, `RAPE.OnSpellCast` is called exactly once with `(shortName, playerClass, spellID)` where `shortName` and `playerClass` come from the Roster.

**Validates: Requirements 1.3, 1.6, 2.1, 4.1**

### Property 3: Realm suffix is stripped before Roster lookup

*For any* unit whose `UnitName` returns a realm-qualified string `"Name-Realm"`, the Roster lookup and the `playerName` argument passed to `OnSpellCast` shall use only `"Name"`.

**Validates: Requirements 2.2**

### Property 4: Duplicate castBarId suppresses dispatch

*For any* `castGUID` (castBarId), if `UNIT_SPELLCAST_SUCCEEDED` fires twice with that same `castGUID`, `RAPE.OnSpellCast` is called at most once — on the first occurrence.

**Validates: Requirements 3.2, 3.3**

### Property 5: Cache is cleared on zone transition

*For any* `castGUID` seen before `PLAYER_ENTERING_WORLD` fires, a subsequent `UNIT_SPELLCAST_SUCCEEDED` with that same `castGUID` shall be treated as a new cast and dispatched normally.

**Validates: Requirements 3.4**

## Error Handling

| Condition | Behavior |
|---|---|
| `UnitName(unitTarget)` returns `nil` | Discard event, no error |
| `UnitName(unitTarget)` returns `UNKNOWNOBJECT` | Discard event, no error |
| `UNIT_SPELLCAST_SUCCEEDED` unavailable for a unit token | `SafeReg` returns false; log `RAPE.Debug` warning; addon continues loading |
| `castGUID` is nil | `seenCasts[nil]` is a valid Lua table key — treated as a single shared key; acceptable since nil castGUID is not a valid Midnight event |

The existing `SafeReg` wrapper already handles `ADDON_ACTION_FORBIDDEN`. No new error-handling infrastructure is needed.

## Testing Strategy

### Unit tests

Focus on specific examples and edge cases:

- `UnitName` returns `nil` → event discarded
- `UnitName` returns `UNKNOWNOBJECT` → event discarded
- Realm-qualified name `"Mage-Silvermoon"` → lookup uses `"Mage"`
- `UNIT_SPELLCAST_SUCCEEDED` registration fails for a unit token → debug warning logged, no Lua error
- `PLAYER_ENTERING_WORLD` clears `seenCasts`

### Property-based tests

Use a Lua property-based testing library (e.g., `lua-quickcheck` or a lightweight custom shrinker). Each test runs a minimum of 100 iterations.

Each test is tagged with:
`-- Feature: castbar-spell-tracking, Property N: <property text>`

| Property | Test description |
|---|---|
| Property 1 | Generate random (unitTarget, castGUID, spellID) where name ∉ Roster OR spellID ∉ TrackedSpellIDs; assert OnSpellCast never called |
| Property 2 | Generate valid (roster member, tracked spellID, fresh castGUID); assert OnSpellCast called once with correct args |
| Property 3 | Generate roster member names; fire event with `"Name-AnyRealm"`; assert OnSpellCast receives bare `"Name"` |
| Property 4 | Generate any valid cast; fire twice with same castGUID; assert OnSpellCast called exactly once |
| Property 5 | Populate seenCasts; fire PLAYER_ENTERING_WORLD; fire same castGUID again; assert OnSpellCast called |
