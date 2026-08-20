**Feature ID:** FPL-001
**Status:** Ready for Development - ready-for-agent
**Owner:** Solo Developer
**Tech Stack:** Godot 4.6, GDScript, ENet
---
## Problem Statement
SHP-001 shipped exactly two upgrades, both flat stat-toggle flags (`max_health_upgrade_owned`, `rod_pull_speed_upgrade_owned`) applied silently via `apply_upgrade_effects_to_player()`. That PRD explicitly scoped out anything beyond these two. Player feedback and design direction both point toward upgrades that are experienced in the world rather than invisible number bumps — a Minecraft-style "build something, interact with it" progression instead of a shop checkbox list.

Separately, this feature's safety premise (island center = safe from the shark) exposed a latent gap: `DangerManager._process_approaching()` has no land-exclusion check, unlike `_process_retreating()` which already respects MapConfig bounds. Without fixing this, "the island center is safe" is not actually true today.
## Solution
A fireplace, pre-placed at the island center (`MapConfig.MAP_CENTER`, same static-scene-node pattern as ShopHut), purchasable once from the shop as a team-shared, permanent unlock (`fireplace_owned: bool`, same flag shape as existing upgrades — no new economy plumbing). Once owned, a player right-clicks it (existing `InteractableComponent` interact action) to sit down and begin healing over time — a toggle, not a hold. Sitting locks the player's movement; the first WASD press auto-stands them and pauses healing (progress preserved, not reset, same as leaving a proximity zone would). Multiple players can sit and heal simultaneously — no exclusivity, no queue.

Heal rate is not a flat number: a full heal (0 → current `max_health`) takes 1/10th of `RoundManager.round_duration`, computed against the player's current `max_health` (so owning the max_health upgrade doesn't distort total heal time). At the default `round_duration = 900.0`, that's a 90-second full heal, ~30-36s to recover from a single shark bite.

This feature also fixes a pre-existing bug in DangerManager: the shark's approach logic gets a land-exclusion check so it can no longer path onto/near the island interior, matching the guard already present in the retreat logic. This is what actually makes the fireplace's placement safe, not just "probably safe because it's far away."
## User Stories
1. As a player, I want a place to heal that feels like a real structure in the world, not a shop menu toggle, so progression feels tangible.
2. As a player, I want healing to take real time and require me to stop what I'm doing, so it's a genuine tradeoff (safety costs playtime) rather than a free top-up.
3. As a player, I want to be able to step away from the fireplace without losing my healing progress, so a short interruption (checking on a teammate, spotting the shark) doesn't fully waste my time invested.
4. As a team, we want multiple of us to be able to heal at once, so recovering after a bad shark encounter doesn't turn into a queue.
5. As a player, I want the fireplace to actually be safe where it's placed, so committing to stand still there isn't secretly risky due to an unrelated shark pathing bug.
6. As a developer, I want heal rate to scale with round length automatically, so changing round duration for balance later doesn't require also retuning the fireplace.
## Implementation Decisions
### Decision 1: Scope — Fireplace-Specific, Reusable Plumbing
This PRD implements the fireplace only, not a general upgrade-system rework. However, purchase/ownership is modeled as a distinct "placed structure" pattern (static scene node + occupancy tracking + one-time flag) separate from the existing "stat flag" pattern (`max_health`, `rod_pull_speed`), so future structure-based upgrades can reuse this shape without a third bespoke system.
### Decision 2: Placement — Pre-Placed, Team-Shared, Single Instance
The fireplace exists in `main.tscn` from scene start, positioned at `MapConfig.MAP_CENTER`, following the exact pattern ShopHut already uses (static `StaticBody3D`, always present, purchase changes its state rather than its existence). No player-chosen placement, no per-player instances — purchase is a single team-wide unlock, consistent with how CoinManager's existing upgrades work.
### Decision 3: No Explicit Safe Zone — Safety By Geography + Bugfix
No new exclusion logic is added to DangerManager for "near the fireplace." Safety comes entirely from the fireplace's placement at island center, where the shark cannot reach. This requires fixing a pre-existing gap: `_process_approaching()` currently has no check against `MapConfig.is_within_radius(..., ISLAND_RADIUS)`, unlike `_process_retreating()` which already guards against island/fishable-band bounds. This fix is a dependency of this feature, not a separately scheduled bugfix — without it, the fireplace's core safety premise is false.
### Decision 4: Sit-Toggle via Right-Click, Not Passive Proximity
Superseded from an earlier passive-proximity design (ZoneManager-style occupancy tracking) to an explicit, deliberate interaction: right-click (the existing interact action, already bound project-wide via `InteractableComponent`, used by ShopHut/StorageBox) toggles sitting on. This reuses the existing one-shot interact pattern exactly — no held-input tracking, no new occupancy system.

Sitting sets an `is_sitting`-style state flag that gates the player's `_physics_process` movement handling, following the same gating pattern already used by `PlayerState.SPECTATE`. Any WASD press while sitting immediately stands the player up (state cleared, movement control returned) and pauses heal progress — functionally identical to the original pause/resume behavior (Decision 5, unchanged), just triggered by movement-while-seated instead of leaving a spatial radius. Re-sitting (right-click again) resumes from wherever progress was left, not from zero.

Rejected: passive proximity-based auto-heal (original design) — risked accidental/ambient healing given the fireplace's placement near the shop hub where players naturally cluster; a deliberate action better fits a meaningful-upgrade-as-commitment framing. Also rejected: held-right-click channel — no precedent for held-input tracking anywhere in the codebase, toggle reuses proven one-shot pattern with zero new input plumbing.
### Decision 5: Multiple Simultaneous Healers, Uncapped
No occupancy cap. ZoneManager's occupancy count pattern (`zone_occupant_counts[i]`) is not capped at 1 by default, so simultaneous multi-player healing falls out of reusing that pattern as-is — not additional work, the lower-effort option compared to adding single-slot exclusivity.
### Decision 6: One-Time Purchase, No Fuel Cost
`fireplace_owned: bool`, purchased once via `CoinManager.request_buy_upgrade()`-style flow (same shape as existing two upgrades), free to use indefinitely after. No recurring resource cost — that role is intentionally reserved for the separate Chum Bucket feature, avoiding two systems competing for the same "feed it fish/coins" mechanic.
### Decision 7: Heal Rate — Round-Duration-Relative
Full heal (0 → current `max_health`) takes `round_duration / 10`. Per-tick interval is computed as `(round_duration / 10) / max_health` seconds per 1 HP, evaluated against the player's current `max_health` at heal-start (so the max_health upgrade doesn't change total heal time, only tick granularity). At default `round_duration = 900.0`: 90s full heal. Automatically rescales if `round_duration` is retuned for balance, no fireplace-side changes needed.
## Testing Decisions
Consistent with existing precedent (`test_zone_manager.gd`, `test_health_component.gd`) — direct method/state assertions, no timer/network dependency in unit tests:
- **Covered:** heal progress accumulates while sitting, pauses (not resets) when movement input stands the player up and resumes correctly on re-sit, movement input is blocked while sitting and immediately restored on stand-up, multiple simultaneous sitters all accumulate independently, heal-tick interval computes correctly from `round_duration` and current `max_health`, purchase flag gates the sit interaction (no heal before purchase), shark approach logic respects island-radius exclusion (new DangerManager test case).
- **Not covered by automated tests:** perceived heal-rate feel / balance — validated via manual playtest same as other tuning in this project.
## Out of Scope
- Player-chosen fireplace placement — fixed at island center only; a build/placement system is a separate, larger feature if ever pursued.
- Recurring fuel/resource cost to use the fireplace — explicitly reserved for Chum Bucket; fireplace is one-time-purchase, free-use forever.
- Single-occupant exclusivity / healing queue — rejected; uncapped simultaneous healing (Decision 5).
- Explicit safe-zone suppression logic in DangerManager — not needed once the land-exclusion bugfix (Decision 3) lands; geography alone provides safety.
- General upgrade-system architecture rework — this PRD implements fireplace specifically; broader reusability is a side effect of the chosen pattern, not a goal in itself (Decision 1).
- Flat/fixed heal rate independent of round length — rejected in favor of round-duration-relative scaling (Decision 7).
## Further Notes
### Dependency: DangerManager Land-Exclusion Fix
This PRD cannot ship without the `_process_approaching()` fix (Decision 3). Treat it as the first implementation step, not an afterthought — the fireplace's entire value proposition depends on it being true.
### Relationship to Chum Bucket
Both features are shop-adjacent, fish/resource-related additions under active discussion. Deliberately kept non-overlapping: fireplace = one-time purchase, no recurring cost, healing utility. Chum bucket = recurring fish-deposit mechanic, attraction/economy utility. Keep this separation if either feature's design shifts later.
### Design Provenance
Follows the project's stated direction (Minecraft-style meaningful upgrades: build/interact with a structure rather than buy an invisible stat bump) discussed prior to this PRD, and reuses existing proven patterns (ShopHut static placement, ZoneManager occupancy tracking, CoinManager flag-based purchase) rather than introducing new architecture where an existing pattern already fits.