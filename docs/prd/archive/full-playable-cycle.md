**Feature ID:** RSK-001

**Status:** Ready for Development -- ready-for-agent

**Owner:** Solo Developer

**Tech Stack:** Godot 4.6, GDScript, ENet

---

## Problem Statement

The current core loop leans on two mechanics that are working against the team's actual near-term goal of validating whether the basic day-to-day fishing/threat loop is fun at all. First, FishingMechanic's reel meter (hold input, chase a moving green zone for 10-20 seconds) is a skill-check the team is not confident serves the game's core tension -- yelling under pressure -- and is the highest-friction, longest-duration action in a loop that needs to be fast and repeatable for short playtest sessions. Second, the shark's escalation math (faster return after each yell) pushes players to speak up under pressure but does so through a hidden-number punishment, and the yell-to-repel channel forces the mic to be both the "I need to warn my team" button and the "I need to defend myself" button simultaneously -- two jobs that pull the mechanic in conflicting directions.

## Solution

Add a new RockManager (host-authoritative sibling to ZoneManager/DangerManager/QuotaManager/RoundManager, matching its broadcast pattern but with its own separate placement/state arrays -- no shared code with ZoneManager) that scatters pickup points around a land annulus outside the water's edge. Players walk to a visible rock point, click to pick up one rock at a time, carry it (one-rock limit, hands must be empty -- overrides the fishing rod), and click to throw it -- no aim-hold, no precision curve. A thrown rock at the approaching shark triggers DangerManager.repel(), a new entry point into the existing retreat transition that bypasses the old yell-based path entirely: yelling stops scaring the shark.

FishingMechanic's REELING state and its entire reel-meter UI subtree are deleted outright. On bite, a single click transitions directly to SUCCESS within a 2.5-second reaction window (otherwise the fish escapes). The shark's pacing is retuned: first appearance at 30-60 seconds, return window at 45-90 seconds. All repels and attacks use flat return timing (escalation math removed). A purely visual day/night swap (night = fishing active, day = fishing ended) is driven by reading RoundManager.fishing_active directly from the per-frame world loop.

## User Stories

### Rock Pickup

1. As a **player**, I want to **see rocks scattered around the island's shoreline**, so that **I always have a nearby source of ammunition against the shark.**
2. As a **player**, I want to **aim my camera at a rock and click to pick it up**, so that **picking up a rock feels consistent with how I already interact with the world.**
3. As a **player**, I want to **only be able to carry one rock at a time**, so that **I have to make repeated trips rather than stockpiling.**
4. As a **player**, I want **picking up a rock to require my hands to be empty**, so that **I can't carry a rock and hold my fishing rod at the same time.**
5. As a **player**, I want **a rock point I picked from to become temporarily unavailable**, so that **I understand it's been consumed.**
6. As a **player**, I want **a picked-up rock point to eventually refill**, so that **the island doesn't run out of ammunition permanently over a long round.**
7. As a **developer**, I want **rock point positions to be procedurally scattered on land (not water) with minimum spacing between them**, so that **placement is automatic and never overlaps or lands in the water.**

### Throwing & Repelling the Shark

1. As a **player**, I want to **click to throw my held rock**, so that **throwing feels immediate and readable, consistent with the game's other instant-feedback actions.**
2. As a **player**, I want **a thrown rock to scare the shark away if it's approaching and roughly in front of me**, so that **I have a real, active counter-play against the threat.**
3. As a **player**, I want **the shark to fully retreat after being hit by a rock**, so that **the payoff for landing a throw is clear and immediate.**
4. As a **player**, I want **yelling to no longer scare the shark away**, so that **rocks are the only real defensive tool against it.**
5. As a **player**, I want **repelling the shark with a rock to give a consistent amount of breathing room every time**, so that **repeated repels don't feel like they're making the shark angrier or faster.**

### Shark Pacing

1. As a **player**, I want **the shark's first appearance to happen sooner into a round**, so that **the threat is established quickly during short playtest sessions.**
2. As a **player**, I want **the shark to return sooner after an attack or a repel**, so that **the danger stays present throughout a short session instead of going quiet for minutes at a time.**

### Instant-Catch Fishing

1. As a **player**, I want to **catch a fish with a single button press the moment it bites**, so that **fishing feels like Minecraft's fishing loop rather than a timing minigame.**
2. As a **player**, I want **a short window after the bite to react before the fish escapes**, so that **there's still some skill/attention required, not a guaranteed catch.**
3. As a **player**, I want to **still be able to manually reel in my line early while waiting for a bite**, so that **an existing affordance I rely on isn't removed as a side effect of the minigame going away.**
4. As a **player**, I want **everything that already happens on a successful catch (feedback ding/flash, personal catch count, quota report) to keep working exactly as it does today**, so that **removing the minigame doesn't regress anything else.**

### Day / Night (Visual Only)

1. As a **player**, I want **the world to look like night while fishing is active and switch to day once fishing ends**, so that **the shift into the shop period is visually legible.**
2. As a **player**, I want **this transition to happen instantly**, so that **it doesn't add waiting or ceremony to an already-fast round transition.**

### Solo/Small-Group Testing

1. As a **developer**, I want to **trigger rock pickup, deplete, and respawn directly by calling internal methods**, so that **I can verify state without a live raycast or a real timer.**
2. As a **developer**, I want to **verify DangerManager.repel()'s transition and flat-return-timing behavior directly**, so that **I can confirm the escalation removal is correct without a live rock throw.**
3. As a **developer**, I want to **verify the bite->click->SUCCESS transition and the preserved 2.5-second miss window directly**, so that **I can confirm the reel-meter removal didn't regress existing bite-handling behavior.**

## Implementation Decisions

### Decision 1: RockManager -- New Sibling Module, Not Folded Into ZoneManager

Although both ZoneManager and the new rock system are host-authoritative, scattered-point systems with occupancy/respawn concerns, they are implemented as two separate modules rather than one. This was a direct reversal mid-design: folding rocks into ZoneManager was considered first (to avoid a third scattered-point module), but was dropped because ZoneManager's occupancy-locking reshuffle logic (zones lock when a player is fishing in them) is conceptually unrelated to rock points' simple per-point deplete/respawn lifecycle. Merging them would force ZoneManager to know about rocks (which it has no business knowing) or force the rock system to inherit a zone-reshuffle machinery it doesn't need -- both worse than a second, leaner module.

### Decision 2: Rock Point Placement -- Procedural Annulus on Land

Rock points are placed procedurally in a ring (annulus) between the water's edge and the island's outer edge, using the same reject-and-retry placement style ZoneManager and DangerManager already use for their own scattered-point placement. Minimum spacing between rock points is enforced during placement. Points are placed once on round start and never reshuffle during a round (unlike fishing zones), though each point individually depletes on pickup and refills after a fixed respawn delay.

### Decision 3: Pickup -- Raycast + Click, Not Proximity Auto-Grab

Pickup is camera-forward raycast against a rock point's collider, confirmed with a left-click (the same physical button already used for casting), mirroring the interaction shape already established by the storage box in the Carryable Fish + Storage Deposit spec. This was also a reversal mid-design: proximity-based auto-grab (walk near a point, it's automatically picked up) was the original direction, chosen for being lower-friction given how plentiful and casual rock pickups are meant to be. It was dropped once the click-to-throw and click-to-cast overlap was worked through and raycast+click landed as the more consistent, deliberate interaction across all three of the game's held-item actions (cast, pick up, throw), at the cost of slightly more aiming friction than auto-grab would have had.

### Decision 4: Held Item -- `holding_rock` Boolean, Not a Generalized Enum

Player holds a single new boolean, `holding_rock`. This is deliberately not a generalized `HeldItem` enum (rod/rock/fish/etc.) even though the Carryable Fish + Storage Deposit spec describes a similar one-item-at-a-time concept for carried fish, because that spec is not yet merged into shipped code and the team has not agreed on a shared held-item interface shape. Building the generalized enum now risks guessing a shape that won't match the Carryable Fish system when it lands. Hardcode the boolean now, generalize later.

### Decision 5: Left-Click Overload -- Pickup, Throw, or Cast, by Priority

A single left-click (`cast_line` action) now serves three purposes, resolved in a strict priority order each time it's pressed:
1. If the player's raycast is currently hitting an available rock point, the click picks it up and no other action is attempted that click.
2. Otherwise, if the player is currently holding a rock, the click throws it in the camera's forward direction (regardless of whether a shark is present).
3. Otherwise, casting proceeds exactly as it does today.

This priority order means a player standing near a rock point who clicks intending to throw a held rock at an oncoming shark will pick up another rock instead -- a deliberate tradeoff favoring "pickup is always accessible" over "you might throw at the air when you meant to pick up." The pickup range is tunable and should be short enough that this conflict rarely matters in practice (you have to be close to a point for pickup to even be available).

### Decision 6: Throw Is Hip-Fire -- No Aim, No Precision Variance

Throwing a held rock is a single, immediate action with no aim-hold state and no randomness/precision curve based on whether the player aimed first. This directly supersedes an idea raised mid-design (hold right-click to aim for more precision, or throw immediately with more randomness) -- that idea was dropped because the right-click is already reserved for the interact action (storage box / shop), and introducing a throw-aim-hold state on a different button would make throw feel heavier and more deliberate than the fast, casual counter-play the team actually wants.

### Decision 7: DangerManager.repel() -- New, Rock-Specific Entry Point Into the Existing Retreat Transition

A new public method on DangerManager is added as a second way to trigger the shark's existing APPROACHING -> RETREATING transition (previously only reachable via `is_yelling`). It performs a simple hit check (the thrown rock's origin/direction against the shark's current position, within a tunable hit radius) and is a no-op if the shark isn't currently in an approacheable state.

### Decision 8: Repel Escalation Removed -- Flat Return Timing for Both Attack and Repel

The existing escalation math (`speed_multiplier`, `delay_multiplier`, `min_swim_speed`, `min_return_delay` -- the mechanism that made the shark swim faster and return sooner after each consecutive yell) is removed entirely, not just retargeted at rocks. Both a successful unrepelled attack and a successful repel result in the same, non-escalating return delay. The same caps and multipliers that previously controlled escalation are deleted from DangerManager's exports.

### Decision 9: Shark Pacing Retune

`initial_spawn_delay` becomes a randomized 30-60 second range (previously a fixed 60 seconds). `respawn_interval_min`/`respawn_interval_max` (the post-attack return window) becomes 45-90 seconds (previously 180-300 seconds). Per Decision 8, this same 45-90 second range is now also used for the post-repel return window.

### Decision 10: REELING State and Reel-Meter UI Deleted Outright

FishingMechanic's `REELING` state, its associated UI subtree (`ReelMeter`/`GreenZone`/`PlayerBar` and their tunable exports), `green_zone_timer`, `reel_timer`'s meter-driving logic, and the `_is_bar_in_zone()` skill-check are all removed outright, not left dormant. This is a clean delete rather than a disable-flag approach, since the team does not intend to re-add this mechanic and leaving dead code in the shipping codebase would create a maintenance burden for no benefit.

### Decision 11: Bite Resolution -- Direct BITE -> SUCCESS on Button Press

With `REELING` removed, a button press during the `BITE` state transitions directly to `SUCCESS`, reusing every downstream step that already exists and already fires correctly today (`personal_catch_count` increment, `personal_catch_changed` emission, `reel_success` signal emission, catch reported to host, and the existing catch-success feedback ding/flash). A 2.5-second miss window after the bite telegraph fires: if the player hasn't clicked within that window, the fish escapes (same `reel_failure` path, same feedback). This preserves a skill window without the overhead of the meter.

### Decision 12: Day/Night -- Inline Poll, No New Signal, Instant Swap

The day/night visual swap reads `RoundManager.fishing_active` directly from inside `world_setup.gd`'s already-running per-frame loop (the same loop that currently drives the FPS counter), rather than introducing a new signal or hook system. This was corrected mid-design after an initial draft proposed a new signal -- the per-frame poll is simpler, has no coupling concerns (one consumer reading a single shared boolean), and avoids adding an unused signal just for this swap.

## Testing Decisions

Good tests here validate observable state and signal outcomes from direct method calls, bypassing the camera raycast, live timers, and live network connections -- consistent with the existing pattern in `test_zone_manager.gd`, `test_danger_manager.gd`, and `test_fishing_mechanic.gd`.

**RockManager** (new test file, mirroring `test_zone_manager.gd`'s structure exactly):
- Point availability lookup
- Nearest-available-point-within-range lookup and its out-of-range sentinel
- Pickup marking a point unavailable
- A pickup request against an already-unavailable point being a clean no-op
- Point respawn after the configured delay
- Minimum-spacing placement retry

**DangerManager** (new tests added to the existing `test_danger_manager.gd`):
- `repel()` transitions APPROACHING -> RETREATING on a qualifying hit and is a no-op otherwise (out of range, wrong state, no shark)
- A successful repel and a successful unrepelled attack both leave the return delay at its flat value (no escalation)

**FishingMechanic** (existing `test_fishing_mechanic.gd`, reel-specific tests replaced):
- The two currently-passing reel-success/reel-failure-via-meter tests are removed, since that behavior no longer exists
- New tests cover bite-state button press transitioning directly to SUCCESS with `personal_catch_count` incremented, and the 2.5-second miss window transitioning to the escape path

Explicitly not covered by automated tests, per existing project precedent: the pickup/throw raycast itself, the day/night visual swap, and the held-rock mesh's visibility to other players -- validated through manual playtesting.

## Out of Scope

- **Generalizing `holding_rock` into a shared `HeldItem` enum** -- deferred until Carryable Fish + Storage Deposit actually merges; building the generalized shape now risks guessing it wrong.
- **Aim-hold / precision-vs-hip-fire throw variant** -- explicitly considered and deferred; this PRD ships hip-fire only.
- **A generic `Repellable` interface/contract shared between the shark and any future threat (e.g. birds)** -- explicitly considered and rejected for this pass; `DangerManager.repel()` is hardcoded and rock-specific.
- **Yelling-scares-fish (or attracts-other-threats) wiring** -- `is_yelling` is left wired and untouched, but no new consumer of it is built in this PRD.
- **Birds, any other new threat type, or any change to QuotaManager/ZoneManager's existing fish-zone behavior** -- untouched by this PRD.
- **Animated day/night transition** -- instant swap only, per Decision 12.
- **Rate-limiting or cooldown on the pickup raycast/click itself** -- not needed under the raycast+click model.

## Further Notes

### Origin

This PRD was produced through an extended grill-me-style interview covering rock spawning, rock-based shark repel, shark pacing, reel-minigame removal, and a purely-visual day/night pass, with several deliberate mid-design reversals recorded above (rocks folded-then-unfolded from ZoneManager; pickup switched from proximity auto-grab to raycast+click; aim-hold/precision-variance for throwing dropped).

### Publishing Note

Following this project's established precedent (see the 4-Player Multiplayer, Round Lifecycle, Round Structure Rework, and Day -> Shop Slice specs), this PRD is published to Notion under Project Loki's Specification section, since this repository has no connected issue tracker.

### Dependency Note

This feature touches shipped, tested code in FishingMechanic and DangerManager directly (not just additive new modules), unlike most of the project's more recent PRDs. It should land as its own reviewed pass, distinct from any unrelated in-flight work on those two files.

### Suggested Build Order

1. **Shark pacing retune** (Decision 9) -- export-var-only, zero state-machine risk, fastest to verify.
2. **RockManager** (Decisions 1-2), tested in isolation per the Testing Decisions above.
3. **Player pickup/throw/holding_rock** (Decisions 3-6).
4. **DangerManager.repel() and yell-removal** (Decisions 7-8), landing together since they're the same transition being rewired.
5. **Reel-minigame removal** (Decisions 10-11) -- highest-risk slice (touches the most existing tested behavior), suggested last so it can be reviewed independent of the rock-throwing work above.
6. **Day/night visual pass** (Decision 12) -- smallest, independent, can land any time relative to the rest.

Each slice should be manually playtested before moving to the next, consistent with this project's existing build-order convention.
