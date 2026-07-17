**Feature ID:** RL-001

**Status:** Ready for Development

**Owner:** Solo Developer

**Tech Stack:** Godot 4.6, GDScript, GD-Sync

---

## Problem Statement

There is currently no concept of a round having a beginning or an end. QuotaManager will happily accumulate `shared_quota` forever with no target to reach. DangerManager spawns sharks and attacks indefinitely. FishingMechanic accepts cast/reel input indefinitely. Nothing ever stops, nothing is ever won or lost, and nothing resets.

This means the core loop the entire game is built around -- catching 20 fish in 15 minutes, or failing as a team -- does not actually exist yet as a playable, endable experience.

## Solution

Add a RoundManager, a new host-authoritative node sibling to DangerManager and QuotaManager, that owns a countdown timer and a target quota. It watches QuotaManager's `quota_updated` signal and ends the round in success the instant the shared quota reaches the target; if the timer runs out first, it ends in failure. On either outcome, it broadcasts `round_active = false` to all clients, which DangerManager and FishingMechanic each gate against to stop their behavior. An end screen shows the result (success/failure, final quota vs target) and offers a host-only restart control that resets all relevant state in place without a scene reload.

## User Stories

### Round Timer

1. As a **player**, I want to **see a countdown timer for the round**, so that **I understand how much time is left to hit quota.**
2. As a **player**, I want the **timer to start the moment the round begins**, so that **there's no ambiguity about when the clock is running.**
3. As a **developer**, I want **the round duration to be a tunable export variable**, so that **I can adjust session length without touching code.**

### Winning the Round

1. As a **player**, I want the **round to end in success the instant our team's shared quota reaches the target**, so that **we get immediate payoff for hitting our goal rather than waiting out the clock.**
2. As a **player**, I want to **see clear confirmation that we succeeded**, so that **the win feels legible and rewarding.**
3. As a **developer**, I want **the quota target to be a tunable export variable**, so that **I can rebalance difficulty without touching code.**

### Failing the Round

1. As a **player**, I want the **round to end in failure if the timer reaches zero and we haven't hit quota**, so that **there's real stakes to the countdown.**
2. As a **player**, I want to **see clear confirmation that we failed, along with our final quota**, so that **I understand how close (or far) we were.**

### Freezing Gameplay at Round End

1. As a **player**, I want **fishing input (casting, reeling) to stop working once the round has ended**, so that **I can't keep playing past the outcome screen.**
2. As a **player**, I want **the danger system to stop spawning or attacking once the round has ended**, so that **a shark can't attack after the round is already decided.**
3. As a **player**, I want **whatever I was doing at the exact moment the round ended (e.g. mid-reel) to simply freeze in place**, so that **the ending doesn't feel like a jarring forced cancellation.**
4. As a **developer**, I want **round-active gating to be a single shared flag that other systems check**, so that **RoundManager doesn't need to know DangerManager's or FishingMechanic's internals.**

### End Screen

1. As a **player**, I want to **see whether we succeeded or failed, clearly and immediately**, so that **I don't have to guess the outcome.**
2. As a **player**, I want to **see our final team quota against the target**, so that **I have a concrete number to react to.**
3. As a **player**, I want **the end screen to be simple with no extra animation or polish**, so that **this feature ships fast and out-of-scope juice can be layered on separately later.**

### Restarting

1. As the **host**, I want **a restart control on the end screen**, so that **I can start a fresh round without anyone leaving the session.**
2. As a **player**, I want **restarting to happen instantly in the same session**, so that **our lobby, connection, and teammates are preserved without re-joining.**
3. As a **non-host player**, I want to **see that we're waiting on the host to restart**, so that **I'm not confused about why nothing is happening.**
4. As a **player**, I want **the team quota to reset to zero on restart**, so that **the new round starts from a clean slate.**
5. As a **player**, I want **the round timer to reset to its full duration on restart**, so that **the new round gets the same amount of time as the last one.**
6. As a **player**, I want **the shark's escalation and any active shark to reset on restart**, so that **the new round doesn't inherit danger difficulty from the last one.**
7. As a **player**, I want **my own fishing state (line, bobber, reel meter) to reset to idle on restart**, so that **I'm not stuck mid-action from the previous round.**
8. As a **player**, I want **my personal catch count to reset to zero on restart**, so that **it reflects only the new round.**
9. As a **player**, I want **to stay exactly where I am in the world when a restart happens**, so that **restart doesn't unexpectedly relocate me.**

### Solo/Small-Group Testing

1. As a **developer**, I want to **trigger win and fail conditions directly by calling internal methods**, so that **I don't have to wait out a real 15-minute timer to verify behavior.**
2. As a **developer**, I want to **verify the round-active guard clauses in DangerManager and FishingMechanic independently**, so that **I can confirm gameplay actually freezes without needing a live round to play out.**
3. As a **developer**, I want to **verify restart resets all relevant state by calling the reset method directly**, so that **I can confirm correctness without a live network connection.**

## Implementation Decisions

### Decision 1: RoundManager as a New Sibling Node

RoundManager is added to `scenes/main.tscn` as a new node, a sibling of DangerManager and QuotaManager, following the same host-authoritative pattern already established by those two: the host runs all real logic (timer ticking, win/fail evaluation) and broadcasts resulting state to every other client.

QuotaManager is not modified to know about rounds, timers, or targets -- it remains exactly what it is today: a dumb counter exposing `report_catch` and `apply_penalty`. RoundManager reaches in only by listening to its existing `quota_updated` signal and reading `shared_quota`.

### Decision 2: Tunable Round Duration and Quota Target

Two `@export` variables on RoundManager:
- `round_duration` (default 900 seconds / 15 minutes)
- `quota_target` (default 20 fish)

Both editable in the Godot Inspector without touching code, matching the tunable-exports pattern already used by DangerManager.

### Decision 3: Round Starts Immediately on Scene Load

RoundManager's countdown starts in its own `_ready()` (host-only, gated on GD-Sync's host check), the same instant DangerManager's spawn timer and the player-spawn loop already start today. No handshake or "all players confirmed spawned" gate is introduced -- consistent with how the rest of the game boots.

### Decision 4: Win Check Fires Instantly, Not at Timer Expiry

RoundManager connects to `quota_manager.quota_updated` and checks `value >= quota_target` on every emission. The moment that's true, the round transitions to success immediately -- it does not wait for the timer to run out. This matches the game's existing bias toward instant feedback (catches ding immediately, quota updates immediately).

Fail is checked only once, when the round's own internal timer reaches zero: if `shared_quota < quota_target` at that point, the round transitions to failure.

### Decision 5: `round_active` as a Shared Read-Only Gate

RoundManager exposes and broadcasts a boolean, `round_active`, defaulting to `true` at round start and set to `false` the instant the round ends (success or failure). This is broadcast the same way DangerManager already broadcasts its shark state.

- DangerManager's `_physics_process` and its spawn/return timer callbacks each add a guard: no-op if `round_active` is false.
- FishingMechanic's cast and reel input handling adds the same guard: no-op if `round_active` is false.

Neither module is torn down, cancelled, or force-transitioned by RoundManager directly -- RoundManager has no reference to either module's internals, consistent with the one-directional coupling already used elsewhere in the project.

### Decision 6: Minimal End Screen

The end screen shows exactly two things: an outcome string ("SUCCESS" / "QUOTA FAILED") and the final quota against the target (e.g. "14 / 20 fish"), plus the restart control. No per-player catch breakdown, no leaderboard, no time-remaining-at-finish stat, and no animation or particle effects.

### Decision 7: Restart Stays in the Same Session, No Scene Reload

Restart does not send anyone back through the lobby scene. `game_manager`'s connected-player tracking already persists independently of any given round and does not need to be rebuilt. Restart is a host-triggered action that resets state in place within `scenes/main.tscn` and freezes/unfreezes the existing end screen.

### Decision 8: Restart Is Host-Only

Consistent with every other shared-session control in this codebase, the restart control is gated on GD-Sync's host check. Non-host clients see the same end screen but with the restart control replaced by a "Waiting for host to restart..." indicator.

### Decision 9: Full Reset Scope on Restart

Restart resets, in this order:
- **RoundManager:** `round_active` -> true, timer reset to `round_duration`
- **QuotaManager:** `shared_quota` -> 0, broadcast via the same sync mechanism `report_catch`/`apply_penalty` already use
- **DangerManager:** escalation reset via its existing `_reset_escalation()`, any active shark despawned, `current_state` -> INACTIVE, spawn timer restarted with `initial_spawn_delay`
- **FishingMechanic** (per player, run locally on each client for its own instance): forced to IDLE via existing cleanup methods, `personal_catch_count` reset to 0

Player world position is explicitly not reset -- no story requires re-spawning players at fixed slots on anything other than initial join, and doing so on restart was not requested.

### Decision 10: Round Outcome Signal Shape

RoundManager emits a single signal, `round_ended(success: bool)`, at the moment the round ends (from either the instant-win check or the timer-expiry fail check), alongside broadcasting `round_active = false` to all clients. The end-screen UI (host and non-host alike) listens for this to know what to display.

## Testing Decisions

Good tests here validate observable state/signal outcomes from direct method calls -- bypassing the real timer and without a live network connection -- consistent with the existing pattern in `test_danger_manager.gd`.

**RoundManager:**
- Given `shared_quota >= quota_target` via a direct `quota_updated` emission, the round transitions to success and `round_ended(true)` is emitted; `round_active` becomes false.
- Given the timer's internal timeout callback fired directly with quota below target, the round transitions to failure and `round_ended(false)` is emitted; `round_active` becomes false.
- Calling the reset method directly resets the timer to `round_duration` and `round_active` back to true.

**DangerManager (one new test in existing `test_danger_manager.gd`):**
- With `round_active` set false, `_physics_process` and spawn/return timer callbacks no-op.

**FishingMechanic (one new test in existing `test_fishing_mechanic.gd`):**
- With `round_active` set false, cast and reel input are ignored.

Explicitly not covered by automated tests: the GD-Sync broadcast of round state to other clients, the end-screen UI itself, and the restart control's host-only visibility -- these fall into the same category as lobby UI and network plumbing, which the project already excludes from its test suite.

## Out of Scope

- **Per-player catch breakdown or leaderboard on the end screen** -- deferred; only the team quota total is shown.
- **End-of-round animation, audio, or screen-shake polish** -- separate roadmap items.
- **Returning to the lobby scene on restart** -- restart stays in-session per Decision 7.
- **Non-host restart** -- restart is host-only per Decision 8.
- **Resetting player world position on restart** -- not requested; players stay where they are.
- **A spawn-confirmation handshake before the round timer starts** -- the round starts immediately on scene load per Decision 3.
- **Escalating quota or difficulty across consecutive rounds** -- each restart resets to the same initial values every time; campaign-style escalation is a separate post-launch roadmap item.

## Further Notes

### Publishing Note

Following the precedent set by the 4-Player Multiplayer spec, this PRD is published to Notion under Project Loki's Specification section and mirrored at `docs/prd/archive/round-lifecycle.md`, since this repository has no connected issue tracker.

### Dependency Note

This feature builds on top of the shipped QuotaManager, DangerManager (shark state machine), FishingMechanic, and the in-progress 4-Player Multiplayer networking. It should land after those remain stable, which they already are in the current codebase.
