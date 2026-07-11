**Feature ID:** RSR-001

**Status:** Ready for Development — ready-for-agent

**Owner:** Solo Developer

**Tech Stack:** Godot 4.6, GDScript, GD-Sync

---

## Problem Statement

The existing Round Lifecycle treats "the fishing timer expired" and "the round is over" as the same event: when the timer hits zero, the round ends, a win/fail state is declared, and (per the current implementation) everything freezes while players wait for the host to restart. This collapses two things that the team now wants to be separate: a **timed fishing phase** and an **untimed free-roam/shop phase** that follows it. Players should be able to keep moving, getting chased by the shark, and (in a future feature) visiting a shop after the clock runs out — not sit frozen at an end screen. The current code has no way to stop new casts without also stopping everything else, and `DangerManager`'s shark is gated on the same "round active" flag, so the shark also goes inert the moment the round is considered over — the opposite of what the team wants.

## Solution

Introduce a second, narrower flag — `fishing_active` — that governs only whether a player may *start* a new cast. It lives directly on `RoundManager`, next to the existing `round_active`/`round_success` fields, and is synced to all clients through the exact same host-authoritative broadcast mechanism already used for those fields. When the round timer expires, only `fishing_active` flips to `false`; `round_active` is left untouched (it no longer has a meaningful "end" for this slice — it stays `true` from round start until the next host-triggered restart). No end-of-round screen is shown when the timer expires; the game simply stops accepting new casts and continues running everything else — movement, the shark, and (in a future feature) the shop — until the host manually restarts.

`DangerManager`'s dependency on round state is removed entirely, not narrowed: the shark spawns, approaches, and attacks on its own schedule regardless of `fishing_active` or `round_active`, including during the post-timer free-roam phase.

In-flight fishing actions (an active bite window or an active reel) are allowed to resolve to their natural conclusion even after `fishing_active` goes false — only the *start* of a new cast is blocked. This avoids a fairness problem where a player mid-reel at the moment the clock hits zero would otherwise have their catch frozen or arbitrarily cancelled for reasons unrelated to their skill.

`EndScreen` and its associated win/fail signal (`round_ended`) are left completely untouched and simply never triggered by this change — they are not deleted, since a future statistics screen (parked as a separate idea) is expected to eventually hook into the same timer-expiry moment, and deleting `round_ended` now would force an unwanted edit to `EndScreen`'s existing signal connection.

## User Stories

### Fishing Phase Ending

1. As a player, I want to be unable to cast a new line once the round timer runs out, so that I understand the fishing phase has ended.
2. As a player, I want to keep moving, jumping, and looking around after the timer runs out, so that the game doesn't feel frozen while I wait for the next round.
3. As a player, I want a fish I'm already reeling in when the timer runs out to resolve normally (success or failure, based on my actual reel performance), so that the exact moment the clock hits zero doesn't arbitrarily cost me a catch I was already winning.
4. As a player, I want a bite I'm already waiting on when the timer runs out to still trigger normally, so that I'm not punished for a fish that was already on its way to biting.
5. As a player, I want no end-of-round screen to appear when the timer runs out, so that I'm free to keep playing without an interruption.

### Shark Behavior After Timer Expiry

1. As a player, I want the shark to keep spawning, approaching, and attacking after the fishing timer has run out, so that the post-fishing period still feels dangerous rather than a safe zone.
2. As a player, I want to still be able to yell to repel the shark during the free-roam period, so that the danger system's existing rules keep working consistently regardless of fishing phase.
3. As a developer, I want the shark's state machine to have no dependency on round or fishing state whatsoever, so that its behavior is simple to reason about and test in isolation.

### Round Restart

1. As a player, I want to be able to cast again immediately once the host restarts the round, so that a new fishing phase begins cleanly.
2. As the host, I want restarting the round to reset the fishing phase for every connected client, not just my own, so that the whole team starts the new round able to fish.

### Solo/Small-Group Testing

1. As a developer, I want to test that new casts are blocked once the fishing phase ends, without needing a live `RoundManager` node in the scene, so that `FishingMechanic` stays testable in isolation.
2. As a developer, I want to verify that in-flight bite and reel states resolve normally regardless of fishing phase, so that I can confirm the "let it finish" behavior is correct without a live round timer.
3. As a developer, I want to verify the shark's spawn, approach, and attack behavior fires correctly with no round-state guard at all, so that I can confirm the removal was complete and didn't leave a partial guard behind.

## Implementation Decisions

### Decision 1: `fishing_active` Lives on `RoundManager`, Not a New Module

`fishing_active` is added as a second boolean field directly on `RoundManager`, alongside the existing `round_active` and `round_success`. It is mutated host-side only and broadcast to every client through the same synchronization call already used for those fields — not a new manager, node, or `GDSync.expose_func`. This follows the project's established host-authority pattern (one flag, one owner, one broadcast path) rather than introducing a second manager for what is functionally one more bit of "what phase is the round in" state that `RoundManager` already owns.

### Decision 2: Timer Expiry Only Flips `fishing_active` — `round_active` Is Untouched

When the round timer times out, the host sets `fishing_active = false` and broadcasts it. `round_active` is not modified by timer expiry at all — it remains `true` from round start until the next host-triggered restart. The existing win/fail branch (`_end_round`, the `round_ended` signal, and `round_success`) is not called by timer expiry. This means, functionally, the "round" as a bounded, endable concept no longer exists for this slice — only the narrower fishing phase has a defined end. `_end_round()`, `round_ended`, and `round_success` are left in place as unused/dormant code rather than deleted, specifically to avoid forcing an edit to `EndScreen`'s existing signal connection to `round_ended`.

### Decision 3: No Signal Emitted on Fishing Phase End

No new signal is introduced for "fishing phase ended." The `fishing_active` value flip itself is the event. A future consumer (e.g. a statistics screen) is expected to observe that flip the same way `EndScreen` currently observes `round_active`/`round_success` — by hooking into the client-side state-sync callback when that future feature is actually built. This avoids adding an unused signal speculatively.

### Decision 4: `fishing_active` Reset Happens in the Client-Facing Restart Function

`fishing_active` is reset to `true` inside the same function that already resets `round_active` and `round_success` for every client during a restart (not inside the host-only portion of the restart flow). This guarantees every client's `fishing_active` is corrected immediately as part of the restart broadcast, rather than depending on some later, unrelated sync event to eventually correct a stale value.

### Decision 5: `FishingMechanic` — Only Cast Initiation Is Gated

Of the several places `FishingMechanic` previously checked round-active state, only the function that decides whether a new cast may begin is changed to check `fishing_active`. Every other state-machine transition (casting-timer completion, bite-timer completion, reel-timer completion, green-zone movement, catch-feedback completion, and the in-process BITE/WAITING checks) is left ungated by fishing phase and continues to run exactly as it does today. The prior "freeze in place if round inactive" behavior is not carried forward for these — an in-flight bite or reel always resolves to a normal outcome, whether or not the fishing phase is still active. The internal lookup used for the cast-gating check follows the same cached, null-safe node-lookup pattern the equivalent lookup already used (falling back to its last known value if the round manager can't be found), preserving compatibility with tests that instantiate `FishingMechanic` without a live round manager in the scene.

### Decision 6: `DangerManager`'s Round-State Guard Is Removed Entirely, Unconditionally

All dependency on round or fishing state is removed from `DangerManager` — not narrowed, not replaced with a different condition. The shark's spawn timer, return timer, and physics-driven approach/attack/retreat logic run purely on their own internal schedule and state machine from the moment the host's danger system starts, with no gating check anywhere referencing round or fishing state. This is intentional: the shark is meant to remain a threat through and beyond the fishing phase, including during free-roam and any future shop period.

### Decision 7: Dead Code Cleanup Is Scoped to What This Change Actually Orphans

Code that becomes unused as a direct result of these changes is removed, with one deliberate exception. In `DangerManager`, the now-unused round-state lookup helper and its cached backing field are deleted outright, since nothing else in the codebase references them and no other file's wiring depends on their existence. In `RoundManager`, by contrast, `_end_round()`, `round_success`, and the `round_ended` signal are *not* deleted, because `EndScreen` still holds a live connection to `round_ended` — removing it would force an otherwise-unrelated edit to a file this feature is not meant to touch. This distinction (delete when clean, retain when removal has cross-file collateral) is the deliberate standard applied throughout this feature, not an inconsistency.

## Testing Decisions

Good tests here validate observable state transitions from direct method calls — bypassing timers and live network connections — consistent with this project's existing testing philosophy (see the existing fishing mechanic and danger manager test suites).

**`RoundManager`:**

- Timer expiry sets `fishing_active` to `false` without modifying `round_active`.
- Restart resets `fishing_active` back to `true` for all clients via the existing client-facing restart path.

**`FishingMechanic`:**

- Casting is blocked when `fishing_active` is false, and this check works correctly even without a live `RoundManager` node present (mirrors the existing pattern of setting the cached value directly in tests).
- An in-flight reel resolves to its normal success/failure outcome regardless of `fishing_active` state — this replaces the previous "noop when round inactive" test, which is deleted since that behavior no longer exists.
- An in-flight bite still triggers and can still be reeled regardless of `fishing_active` state — same replacement/deletion approach as above.

**`DangerManager`:**

- Spawn-timer timeout, return-timer timeout, and physics-driven approach all continue to function with no round/fishing-state guard present. The three existing tests that asserted noop-when-inactive behavior are deleted, since that behavior is intentionally removed.

**Prior art:** Follow the existing `test_round_manager.gd`, `test_fishing_mechanic.gd`, and `test_danger_manager.gd` patterns exactly — instantiate the relevant node directly, drive state via internal methods (bypassing timers), and assert on resulting state. No mocking framework, consistent with the rest of the project.

## Out of Scope

- **Statistics screen at end of fishing phase** — a separate, not-yet-specced idea (tracked in the project's Ideas list) for showing per-player competitive statistics when the fishing phase ends, with a close button before free-roam/shop continues. This feature only needs to ensure the underlying `fishing_active` transition is a clean, observable event a future stats screen can hook into — it does not build the screen itself.
- **Any new signal for "fishing phase ended"** — deliberately not added; deferred until the statistics screen (or another consumer) actually needs it.
- **Deleting `_end_round()`, `round_ended`, `round_success`, or any change to `EndScreen`** — explicitly retained as dormant code for this pass.
- **A "host force-ends the round early" control** — not requested; `_end_round()` remains dormant rather than being wired to a new manual trigger.
- **Any change to the shop, carryable fish, or storage systems described in the Day → Shop Slice PRD** — this feature only establishes the fishing-phase/free-roam split those systems will eventually build on top of.

## Further Notes

### Relationship to the Day → Shop Slice (Pre-Demo) Spec

This PRD implements Decisions 3 and 4 from the existing `Day → Shop Slice (Pre-Demo)` specification in full detail, resolved through direct discussion rather than left as prose-level decisions. It should land before the rest of that spec's slices (carryable fish/storage, shop hut, player health) since those all assume the fishing-phase/free-roam split already exists.

### Publishing Note

Following this project's established precedent (see the 4-Player Multiplayer, Round Lifecycle, and Day → Shop Slice specs), this PRD is published to Notion under Project Loki's Specification section, since this repository has no connected issue tracker with a `ready-for-agent` label workflow.

### Fairness Rationale (Recorded for Future Reference)

The decision to let in-flight bites/reels resolve normally past the timer cutoff, rather than cancelling them, was made deliberately: cancelling to idle would penalize players based on incidental timing relative to a clock they can't precisely see, not on their actual reel performance. Since new casts are already blocked the instant the timer expires, allowing already-committed actions to finish introduces no exploit — it only completes actions a player was already engaged in before the cutoff.
