**Feature ID:** ZFP-001
**Status:** Ready for Development - ready-for-agent
**Owner:** Solo Developer
**Tech Stack:** Godot 4.6, GDScript, ENet
---
## Problem Statement
The `is_yelling` signal (VoiceChatManager.yelling_state_changed) is fully wired end-to-end - amplitude detection, hysteresis, network sync via Player.sync_yelling - but nothing downstream consumes it for fish behavior. RSK-001 explicitly deferred this: yelling's effect on the shark was removed, with `is_yelling` left wired specifically because a fish-scare mechanic was expected to consume it later. Right now yelling has zero gameplay cost to the fishing loop, which weakens the core communication-cost tension the game is built around (warn your team, lose your fish).

Separately, ZoneManager placement already excludes the island interior via `water_boundary_margin` (_placement_bounds()), but this value has never been tuned against the current island scale (MapConfig.ISLAND_RADIUS = 10.0) and may not read as "near shore but not too near" in practice.
## Solution
### Part 1: Yell Scares Fish (new)
While a player is yelling (`is_yelling == true`, sustained - not edge-triggered), any fishing zone within a fixed radius of that player's current position is repeatedly relocated to the farthest eligible point from the player, on a fixed interval, until yelling stops. This applies globally - any zone in range, regardless of occupancy or fight state - and overrides ZoneManager's existing occupancy lock (which normally protects a zone from reshuffling while someone's actively fishing it). If a teammate is mid-fight (BITE state) in an affected zone, the fight is interrupted via the existing `on_fish_fled()` path (same mechanism already used for shark attacks), giving consistent, already-tested failure feedback.
### Part 2: Fish Zone Min Distance (tuning only)
No new code. `water_boundary_margin` (export on ZoneManager, default 1.5) enforces a shoreline-relative minimum distance via the inner bound in _placement_bounds(). Playtested 2026-08-19 against MapConfig.ISLAND_RADIUS = 10.0: 1.5 reads as "near shore but not too near", so the default was retained and no placement-logic changes were required.
## User Stories
1. As a player, I want yelling to scare nearby fish away, so that warning my team about danger has a real, felt cost.
2. As a player, I want fish to keep fleeing for as long as I keep yelling, so that sustained panic (e.g. shouting about an approaching shark) feels proportionally costlier than a short shout.
3. As a player, I want fish to flee toward the far side of my position (not randomly), so that the behavior reads as "scared of me" rather than arbitrary.
4. As a player, I want yelling to interrupt an active bite/fight if it's caught in the scare radius, so that the cost is real even when I'm mid-catch, consistent with how shark attacks already interrupt fights.
5. As a developer, I want the scare radius to match the existing voice proximity reference distance, so that the range a player can be heard roughly matches the range they can scare fish, instead of two unrelated tunables.
6. As a developer, I want the min-distance-from-shore rule to reuse the already-shipped `water_boundary_margin` export, so that this slice doesn't duplicate placement logic that already exists.
## Implementation Decisions
### Decision 1: Global Trigger, Lock Override
Any zone within `yell_scare_radius` of the yelling player is affected, regardless of which player (if any) currently occupies it. This intentionally overrides ZoneManager's occupancy lock (`zone_occupant_counts[i] > 0` skip in _reshuffle_unoccupied_zones) - that lock exists for the timer-based reshuffle to protect fairness, but yell-triggered relocation is a deliberate player-caused cost and needs teeth against the yeller's own zone too, not just empty ones.
### Decision 2: Scare Radius = Voice Reference Distance (Manual Copy)
`yell_scare_radius` is set to 8.0, matching voice_chat_network.tscn's AudioStreamPlayer3D.unit_size. This is a manual copy, not a shared reference - unit_size is a volume-falloff reference point, not a hard audible cutoff (max_distance is currently 0.0, meaning no real cutoff exists yet per PVC-001). Documented explicitly so this doesn't silently drift once Proximity Voice gets its real max_distance tuning pass; revisit then.
### Decision 3: Sustained Trigger, Not Edge-Triggered
Hooks VoiceChatManager.yelling_state_changed to start a repeating scare tick while `is_yelling == true`, not a one-shot on the rising edge. Re-running the full relocation every frame would just make zones twitch uselessly, so the tick runs on a fixed interval instead.
### Decision 4: Rescare Interval
`yell_rescare_interval: float = 1.5` (exported, tunable). While yelling continues, zones in range are re-evaluated and relocated every 1.5s, not continuously. Stops immediately when yelling_state_changed fires false.
### Decision 5: Relocation Target - Farthest From Yeller
Relocation picks the farthest eligible point from the yelling player's current position (not the zone's own previous center, not island center), still respecting existing _placement_bounds() (shoreline margin + fishable band edge) and min_zone_spacing from other zones. Reuses the existing _pick_zone_center_excluding-style candidate search, but scores candidates by distance-from-yeller instead of pure random acceptance.
### Decision 6: Fight Interruption via Existing Path
If an affected zone is occupied by a player in BITE state (actively fighting), the yell relocation calls `on_fish_fled()` on that player's FishingMechanic - identical to the existing shark-attack interrupt path (_broadcast_fish_fled_rpc). No new interrupt logic; reuses proven, tested behavior (reel_failure emit, fight state reset).
### Decision 7: Fish Zone Min Distance - No New Code
`water_boundary_margin` already exists and gates placement via _placement_bounds()'s inner bound (MapConfig.ISLAND_RADIUS + zone_radius + water_boundary_margin). Playtesting kept the default at 1.5; no logic changes.
## Testing Decisions
Consistent with existing precedent (test_zone_manager.gd, test_danger_manager.gd) - bypass timers/network, call methods and assert state/signals directly:
- **Covered:** scare-trigger overrides occupancy lock (zone relocates even with `zone_occupant_counts[i] > 0`), relocation target is farther from the yeller position than the original center, rescare fires on the configured interval while sustained, stops firing once yelling stops, fight interruption calls `on_fish_fled()` and emits reel_failure for an affected in-fight zone.
- **Not covered by automated tests:** actual voice amplitude detection (unchanged, already excluded per test_voice_chat_manager.gd precedent), perceived radius/distance feel - validated via manual playtest same as other spatial tuning in this project.
## Out of Scope
- Changing unit_size/max_distance on the voice proximity system - out of scope for this slice; Proximity Voice (PVC-001) owns that tuning, this slice only borrows the current value once.
- Widening scare radius based on yell duration/volume - flat radius only; scaling radius by sustained duration was considered and explicitly deferred.
- Exempting active fights from the scare - rejected; fights ARE affected (Decision 6), consistent with the original "yelling saves crew but loses fish" design intent.
- New min-distance-from-shore logic - not needed, `water_boundary_margin` already covers this (Decision 7).
- Changing the timer-based idle reshuffle (_on_reshuffle_timer_timeout) - unaffected by this feature; yell-triggered relocation is additive, not a replacement for the existing periodic reshuffle.
## Further Notes
### Build Order
Part 1 (Yell Scares Fish) has no dependency on Island Shape and can be built immediately. Part 2 (min-distance tuning) was originally sequenced to wait on Island Shape landing - Island Shape has since shipped (MapConfig.ISLAND_RADIUS = 10.0) and Part 2 shipped as the #169 tuning pass (2026-08-19, default retained at 1.5), so it is not separate scheduling.
### Design Provenance
This PRD resolves the deferred hook RSK-001 left in place (`is_yelling` wired but unconsumed by fish behavior) and restores the original MVP design intent around yelling as a communication-cost mechanic, adapted for the current zone-based fishing system rather than the original flat-radius flee model.