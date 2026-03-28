# Implementation Plan: castbar-spell-tracking

## Overview

Modify `Core/EventHandler.lua` to replace `COMBAT_LOG_EVENT_UNFILTERED` with `UNIT_SPELLCAST_SUCCEEDED`, registered per unit token via a loop. Add a `seenCasts` deduplication cache keyed on `castGUID` (castBarId), and clear it on `PLAYER_ENTERING_WORLD`. No other files are touched.

## Tasks

- [x] 1. Remove the combat log listener from EventHandler.lua
  - Delete `SafeReg("COMBAT_LOG_EVENT_UNFILTERED")` from the `ADDON_LOADED` block
  - Delete the `OnCombatLogEvent()` function and its dispatch branch from the event table
  - _Requirements: 1.1_

- [x] 2. Add seenCasts cache and OnUnitSpellCastSucceeded handler
  - [x] 2.1 Declare the deduplication cache
    - Add `local seenCasts = {}` as a module-local at the top of `Core/EventHandler.lua`
    - _Requirements: 3.1_

  - [x] 2.2 Implement OnUnitSpellCastSucceeded
    - Write `local function OnUnitSpellCastSucceeded(event, unitTarget, castGUID, spellID)` with the five-step logic from the design: dedup check → spell filter → name resolution → roster filter → record + dispatch
    - Strip realm suffix via `strsplit("-", fullName)` before Roster lookup
    - Guard against `nil` or `UNKNOWNOBJECT` from `UnitName`
    - _Requirements: 1.3, 1.4, 1.5, 1.6, 2.1, 2.2, 2.3, 3.2, 3.3, 4.1_

  - [ ]* 2.3 Write property test — Property 1: non-roster/untracked events ignored
    - **Property 1: Non-roster and untracked events are silently ignored**
    - Generate random `(unitTarget, castGUID, spellID)` where name ∉ Roster OR spellID ∉ TrackedSpellIDs; assert `OnSpellCast` is never called
    - Tag: `-- Feature: castbar-spell-tracking, Property 1`
    - **Validates: Requirements 1.4, 1.5**

  - [ ]* 2.4 Write property test — Property 2: valid cast dispatches correct arguments
    - **Property 2: Valid cast dispatches correct arguments**
    - Generate valid `(roster member, tracked spellID, fresh castGUID)`; assert `OnSpellCast` called exactly once with `(shortName, playerClass, spellID)`
    - Tag: `-- Feature: castbar-spell-tracking, Property 2`
    - **Validates: Requirements 1.3, 1.6, 2.1, 4.1**

  - [ ]* 2.5 Write property test — Property 3: realm suffix stripped
    - **Property 3: Realm suffix is stripped before Roster lookup**
    - Generate roster member names; fire event with `"Name-AnyRealm"`; assert `OnSpellCast` receives bare `"Name"`
    - Tag: `-- Feature: castbar-spell-tracking, Property 3`
    - **Validates: Requirements 2.2**

  - [ ]* 2.6 Write unit tests for OnUnitSpellCastSucceeded edge cases
    - `UnitName` returns `nil` → event discarded, `OnSpellCast` not called
    - `UnitName` returns `UNKNOWNOBJECT` → event discarded
    - Realm-qualified name `"Mage-Silvermoon"` → lookup and dispatch use `"Mage"`
    - _Requirements: 2.2, 2.3_

- [x] 3. Register UNIT_SPELLCAST_SUCCEEDED for all unit tokens and wire dispatch
  - In the `ADDON_LOADED` block, build the unit list and register via loop:
    ```lua
    local units = {"player"}
    for i = 1, 5  do units[#units+1] = "party"..i end
    for i = 1, 40 do units[#units+1] = "raid"..i  end
    for _, unit in ipairs(units) do
        SafeReg("UNIT_SPELLCAST_SUCCEEDED", unit)
    end
    ```
  - If `SafeReg` returns false for any unit, emit `RAPE.Debug` warning and continue
  - Add `UNIT_SPELLCAST_SUCCEEDED = OnUnitSpellCastSucceeded` to the event dispatch table
  - _Requirements: 1.2, 4.4_

  - [ ]* 3.1 Write unit test — registration failure per unit token
    - Simulate `SafeReg` returning false for one or more unit tokens; assert debug warning is logged and no Lua error is raised
    - _Requirements: 4.4_

- [x] 4. Clear seenCasts on PLAYER_ENTERING_WORLD
  - Add `PLAYER_ENTERING_WORLD = function() seenCasts = {} end` to the event dispatch table
  - _Requirements: 3.4_

  - [ ]* 4.1 Write property test — Property 4: duplicate castGUID suppresses dispatch
    - **Property 4: Duplicate castBarId suppresses dispatch**
    - Fire `UNIT_SPELLCAST_SUCCEEDED` twice with the same `castGUID`; assert `OnSpellCast` called exactly once
    - Tag: `-- Feature: castbar-spell-tracking, Property 4`
    - **Validates: Requirements 3.2, 3.3**

  - [ ]* 4.2 Write property test — Property 5: cache cleared on zone transition
    - **Property 5: Cache is cleared on zone transition**
    - Populate `seenCasts`; fire `PLAYER_ENTERING_WORLD`; fire same `castGUID` again; assert `OnSpellCast` is called
    - Tag: `-- Feature: castbar-spell-tracking, Property 5`
    - **Validates: Requirements 3.4**

  - [ ]* 4.3 Write unit test — PLAYER_ENTERING_WORLD clears cache
    - Seed `seenCasts` with known keys; fire `PLAYER_ENTERING_WORLD`; assert table is empty
    - _Requirements: 3.4_

- [ ] 5. Final checkpoint
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for a faster MVP
- Only `Core/EventHandler.lua` is modified — CooldownTracker, SpellDB, and UI are untouched
- Property tests should use `lua-quickcheck` or a lightweight custom shrinker, minimum 100 iterations each
