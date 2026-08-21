**Feature ID:** MOON-001
**Status:** Ready for Development - ready-for-agent
**Owner:** Solo Developer
**Tech Stack:** Godot 4.6, GDScript, ENet
---
## Problem Statement
During the fishing/night phase, players have no ambient way to gauge how much round time remains. The countdown only exists as an internal Timer on the host (`round_manager.gd`); clients never receive elapsed/remaining time, only one-shot state flags (`round_active`, `round_success`, `fishing_active`) at transition moments. Players currently have no in-world cue for round pacing - they'd have to guess or ask.
## Solution
A billboarded moon sprite arcs across the sky (horizon → zenith → horizon) over the course of the fishing/night phase, reaching the far horizon exactly as the round timer would expire. The arc position is driven by client-local elapsed time, anchored the instant each peer's own `fishing_active` flips true - no new networked value, no new RPC. It's a self-contained scene (`world/moon_arc.gd` + `.tscn`) that polls RoundManager the same way `world_setup.gd` already does for day/night lighting.
## User Stories
1. As a player, I want to see a moon arcing across the sky during the fishing phase, so that I have an ambient sense of how much round time is left without checking a clock or asking teammates.
2. As a player, I want the moon's position to be readable from anywhere on the island, so that it works as passive information regardless of what I'm doing.
3. As a player, I want the moon to disappear/reset when the fishing phase ends, so that it doesn't linger and mislead me during the day/shop phase.
4. As a player joining or reconnecting mid-round, I want to see a moon in a reasonable position rather than a broken or missing one, so that the visual doesn't feel glitched.
5. As a player, when the host restarts the round, I want the moon to reset to the horizon and begin a fresh arc, so that it accurately reflects the new round.
6. As a developer, I want the arc-position math to be a pure, unit-testable function, so that its correctness can be verified without spinning up the full scene tree.
7. As a developer, I want this feature to introduce no new networked state, so that it stays purely cosmetic and can't desync gameplay-critical values.
## Implementation Decisions
- Visual form: A billboarded 2D sprite (not a 3D mesh, not a skybox/shader effect), matching the precedent set by the Storage Fish Count label and staying cheap under the project's `gl_compatibility` rendering profile.
- What it tracks: The fishing/night countdown only (`round_duration`, gated by `fishing_active`), 1:1 with the same state `world_setup.gd` already uses for day/night sky transitions. It does not track the day/shop phase.
- Sync strategy - no new RPC: `Time.get_ticks_msec()` is per-process uptime and is not comparable across host/client, so a synced timestamp anchor was rejected (mirrors why `fishing_mechanic.gd`'s bobber-flight code stamps `_flight_start_time` locally rather than syncing a raw tick value). Instead, `moon_arc.gd` polls RoundManager.fishing_active every `_process` tick and stamps its own local `_local_anchor_time = Time.get_ticks_msec()` the instant it detects a false->true edge (mirrors `world_setup.gd`'s existing `_last_fishing_active` edge-detection pattern). No new value is added to `_apply_synced_state.rpc(...)` or any other RPC.
- Late-join / drift tradeoff (accepted): Because the anchor is stamped locally per-peer rather than derived from a true shared elapsed-time value, a player who joins mid-round will see the moon start its arc from their join moment rather than at the mathematically correct mid-arc position. This is accepted as harmless since the feature is ambient/cosmetic, not a gameplay-critical sync (unlike shared quota). A future iteration could replace this with a synced elapsed-seconds value on `_apply_synced_state` if late-join accuracy becomes a priority.
- Restart handling: `restart_round()`'s `_apply_restart.rpc()` also flips `fishing_active` false->true, which the same edge-detection catches automatically - no special-case logic needed for restarts.
- Arc geometry: A fixed-plane elliptical arc, horizon → zenith → horizon, computed by a pure function `progress: float -> Vector3` (`progress` = clamped [0.0, 1.0] fraction of elapsed-vs-round_duration). New MapConfig-style constants define the arc: a horizontal half-span radius and a peak height, centered on `MapConfig.MAP_CENTER`. `pos = center + Vector3(cos(θ) * radius, sin(θ) * height, 0)` where `θ = progress * PI`.
- Clamping: `progress` is clamped to [0.0, 1.0] defensively, since debug/test tooling in this codebase (e.g. `round_flow_driver.gd`) mutates `round_duration` after a round has already started, which could otherwise overshoot the arc past the horizon.
- Ownership: A new self-contained scene, `world/moon_arc.gd` + `.tscn`, following the same deep-module pattern as Storage Fish Count, Shop Hut, and Fireplace - its only external dependency is reading RoundManager's `fishing_active` state (via `get_node_or_null("/root/main/RoundManager")` polling, matching `world_setup.gd`'s existing convention). Not folded into `world_setup.gd` itself, so it can be unit tested in isolation.
## Testing Decisions
- Module under test: The pure arc-math function (`progress -> Vector3`) and the edge-detection/anchor-stamping logic, tested the same way `MapConfig.is_within_radius` and `fishing_mechanic._compute_launch_velocity` are - as standalone pure-function tests requiring no scene tree.
- What's asserted: Correct position at `progress = 0.0` (horizon start), `progress = 0.5` (zenith), `progress = 1.0` (horizon end, opposite side), and that out-of-range progress values clamp correctly. Also: that a local anchor timestamp is (re-)stamped only on a `fishing_active` false->true edge, not on every frame while true, and not on a true->false edge.
- Out of scope for testing: Visual/rendering details (sprite art, billboard orientation correctness, exact arc radius/height tuning) are a playtest/visual-review concern, consistent with how Storage Fish Count treated its own rendering details.
## Out of Scope
- Any networked/synced elapsed-time value - this iteration is purely local-anchor-based, accepting the late-join drift tradeoff described above.
- Tracking or visualizing the day/shop phase.
- A literal 3D moon mesh or skybox/shader-based effect - sprite only for this iteration.
- Any gameplay effect tied to moon position (e.g. no danger-spawn-rate changes, no visual warnings at specific arc positions) - purely a passive progress indicator.
- Changes to `round_manager.gd`'s timer, state machine, or existing RPCs.
## Further Notes
- This feature is roadmap item #2 in the Phase 2 (Pre-Demo) plan, directly after Storage Fish Count and ahead of Seagull Fish Theft, Chum Bucket, Player Rod Pull, and Fish Slap & Water Float.
- Exact arc radius/height constants and sprite art are visual-polish decisions to be tuned during implementation/playtest, same as Storage Fish Count's label offset/sizing.
- If late-join accuracy is later prioritized, the natural extension is adding a synced elapsed-seconds value to `_apply_synced_state.rpc(...)` (option considered and deferred during design, see Implementation Decisions).
