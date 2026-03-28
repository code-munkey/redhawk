# Requirements Document

## Introduction

MonkeyTracker currently tracks group cooldowns by listening to `COMBAT_LOG_EVENT_UNFILTERED` and parsing `SPELL_CAST_SUCCESS` subevents. In WoW: Midnight, the public combat log is no longer available. This feature replaces that mechanism with `UNIT_SPELLCAST_SUCCEEDED`, which fires per unit token (player, party1–5, raid1–40) and provides `spellID` and the unit token directly — neither of which is secret. The rest of the addon (CooldownTracker, UI) remains unchanged — only the event detection layer is replaced.

## Glossary

- **EventHandler**: The MonkeyTracker module (`Core/EventHandler.lua`) responsible for registering WoW events and dispatching to internal handlers.
- **CooldownTracker**: The MonkeyTracker module (`Core/CooldownTracker.lua`) that records active cooldowns and exposes them to the UI.
- **SpellDB**: The MonkeyTracker module (`Core/SpellDB.lua`) containing the set of tracked spell IDs and their metadata.
- **TrackedSpellIDs**: The reverse-lookup table `RAPE.TrackedSpellIDs` built from SpellDB, used for O(1) spell filtering.
- **castBarId**: The value carried in the `castGUID` parameter of `UNIT_SPELLCAST_SUCCEEDED` (marked "neversecret") that uniquely identifies a specific cast instance, used for deduplication.
- **UNIT_SPELLCAST_SUCCEEDED**: The WoW client event that fires per unit token when a unit completes a spell cast. Signature: `event, unitTarget, castGUID, spellID`. In WoW: Midnight, `castGUID` carries the `castBarId`.
- **unitTarget**: The unit token string (e.g. `"player"`, `"party1"`, `"raid3"`) passed as the first payload argument of `UNIT_SPELLCAST_SUCCEEDED`.
- **Roster**: The `RAPE.Roster` table mapping player names to class tokens, maintained by CooldownTracker.
- **OnSpellCast**: The existing `RAPE.OnSpellCast(playerName, playerClass, spellID)` function in CooldownTracker that records a cooldown entry.

---

## Requirements

### Requirement 1: Replace Combat Log Listener with UNIT_SPELLCAST_SUCCEEDED

**User Story:** As a raid member using MonkeyTracker in WoW: Midnight, I want the addon to detect group spell casts without relying on the combat log, so that cooldown tracking continues to work after the public combat log is removed.

#### Acceptance Criteria

1. THE EventHandler SHALL unregister `COMBAT_LOG_EVENT_UNFILTERED` during the `ADDON_LOADED` initialization sequence.
2. THE EventHandler SHALL register `UNIT_SPELLCAST_SUCCEEDED` for each of the following unit tokens during `ADDON_LOADED`: `"player"`, `"party1"` through `"party5"`, and `"raid1"` through `"raid40"`.
3. WHEN `UNIT_SPELLCAST_SUCCEEDED` fires, THE EventHandler SHALL extract `unitTarget`, `castGUID` (castBarId), and `spellID` from the event payload.
4. WHEN `UNIT_SPELLCAST_SUCCEEDED` fires for a unit whose resolved name is not in the current Roster, THE EventHandler SHALL ignore the event without calling `OnSpellCast`.
5. WHEN `UNIT_SPELLCAST_SUCCEEDED` fires for a `spellID` not present in `TrackedSpellIDs`, THE EventHandler SHALL ignore the event without calling `OnSpellCast`.
6. WHEN `UNIT_SPELLCAST_SUCCEEDED` fires for a Roster member casting a TrackedSpellID, THE EventHandler SHALL call `RAPE.OnSpellCast(playerName, playerClass, spellID)` with the resolved player name and class from the Roster.

### Requirement 2: Resolve Player Identity from Unit Token

**User Story:** As a MonkeyTracker user, I want spell casts to be attributed to the correct player, so that cooldowns are displayed under the right name.

#### Acceptance Criteria

1. WHEN `UNIT_SPELLCAST_SUCCEEDED` fires, THE EventHandler SHALL resolve the player name from the unit token using `UnitName(unitTarget)`.
2. WHEN `UnitName` returns a realm-qualified name (e.g. `"PlayerName-RealmName"`), THE EventHandler SHALL strip the realm suffix before Roster lookup, consistent with existing name handling.
3. IF `UnitName(unitTarget)` returns nil or `UNKNOWNOBJECT`, THEN THE EventHandler SHALL discard the event.

### Requirement 3: castBarId Deduplication

**User Story:** As a MonkeyTracker user, I want each spell cast to be recorded exactly once, so that cooldown timers are not reset or duplicated by repeated event firings for the same cast.

#### Acceptance Criteria

1. THE EventHandler SHALL maintain a deduplication cache mapping `castBarId` to a boolean, scoped to the current session.
2. WHEN `UNIT_SPELLCAST_SUCCEEDED` fires with a `castGUID` already present in the deduplication cache, THE EventHandler SHALL ignore the event.
3. WHEN `UNIT_SPELLCAST_SUCCEEDED` fires with a `castGUID` not present in the deduplication cache, THE EventHandler SHALL record the `castGUID` in the cache before calling `OnSpellCast`.
4. WHEN `PLAYER_ENTERING_WORLD` fires, THE EventHandler SHALL clear the deduplication cache to prevent unbounded memory growth across zone transitions.

### Requirement 4: Preserve Existing Downstream Behavior

**User Story:** As a MonkeyTracker user, I want the cooldown display and all other addon features to work identically after the event source change, so that I do not need to change how I use the addon.

#### Acceptance Criteria

1. THE EventHandler SHALL call `RAPE.OnSpellCast` with the same three-argument signature `(playerName, playerClass, spellID)` that the combat log handler previously used.
2. THE CooldownTracker SHALL require no modifications to its `OnSpellCast`, `GetActiveCooldowns`, or roster management functions as a result of this change.
3. THE SpellDB SHALL require no modifications to spell entries or `TrackedSpellIDs` as a result of this change.
4. WHEN the addon is loaded in an environment where `UNIT_SPELLCAST_SUCCEEDED` is unavailable, THE EventHandler SHALL log a debug warning and continue loading without error.
