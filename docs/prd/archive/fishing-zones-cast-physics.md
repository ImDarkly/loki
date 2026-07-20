**Feature ID:** FZP-001

**Status:** Ready for Development

**Owner:** Solo Developer

**Tech Stack:** Godot 4.6, GDScript

---

## Problem Statement

The shipped Core Fishing Mechanic teleports the bobber instantly to a random point in front of the player on cast, and rolls for a bite anywhere that point lands. This makes casting feel weightless and makes location meaningless — every cast in every direction has identical odds, and there is no concept of \"good\" vs \"dead\" water like in Stardew Valley. This PRD does not edit the shipped Core Fishing Mechanic spec or its decisions — those already exist in production and are tested. It supersedes their behavior going forward with two additive changes: a real projectile arc for the cast, and Stardew-style designated fishing zones that gate whether a bite can ever occur, with those zones periodically reshuffling position during a round.

## Solution

On cast, the bobber launches from the rod tip and flies to the target position along a gravity-driven arc over a tunable flight duration, instead of appearing instantly. Separately, a new host-authoritative ZoneManager node owns 2-3 circular fishing zones (fixed radius, random position) placed on the water. A cast is never blocked — the player can always cast, and the bobber always flies and lands wherever aimed. But when the bite timer would normally fire, the mechanic checks whether the cast target falls inside any zone. Inside a zone: bite rolls exactly as today, and the player's presence locks that zone in place until they leave. Outside every zone: no bite ever occurs for that cast; after the same 3-8 second wait, \"nothing's biting\" feedback plays and the mechanic returns to idle automatically. Unoccupied zones periodically reshuffle to new random positions on a randomized timer, visualized with a minimal translucent marker so players can see where the good water currently is.

## User Stories

### Cast Physics

1. As a player, I want my bobber to fly through the air on an arc when I cast, so that casting feels physical instead of teleporting the line into place.
2. As a player, I want the flight to take a believable, brief amount of time, so that casting still feels responsive and doesn't slow down the loop.
3. As a player, I want to see the same arc when a teammate casts, so that their fishing is legible from the outside.

### Fishing Zones — Core Behavior

1. As a player, I want fish to only bite in certain designated areas of the water, so that where I cast actually matters, like Stardew Valley.
2. As a player, I want to be able to cast anywhere, including outside a zone, so that I'm never blocked from casting itself — I just won't get a bite there.
3. As a player, I want clear feedback when nothing bites, so that I understand my cast landed in the wrong spot rather than assuming something is broken.
4. As a player, I want the wait before \"nothing's biting\" feedback to feel like a real wait, not an instant rejection, so that a dead-zone cast doesn't feel jarringly different from a live one until the moment it resolves.
5. As a player, I want to see where the fishing zones currently are on the water, so that I'm not aiming at invisible targets, especially once they start moving.

### Zone Reshuffling

1. As a player, I want the good fishing spots to move periodically during a round, so that the map doesn't calcify into memorized GPS pins after the first few minutes.
2. As a player, I want a zone I'm actively waiting for a bite in to never move out from under me, so that the shuffle never invisibly turns what should have been a real bite into a dead-zone miss through no fault of my own.
3. As a player, I want a zone to stay protected from reshuffling for as long as anyone is fishing in it, so that overlapping teammates aren't punished by each other's timing.
4. As a player, I want a zone that just became free to simply rejoin the normal reshuffle schedule, so that there's no exploitable \"bait people away then it instantly moves\" trick.
5. As a developer, I want new zone positions to avoid overlapping each other and to stay fully inside the water's boundary, so that placement never produces a broken or half-submerged zone.

### Solo/Small-Group Testing

1. As a developer, I want to trigger the bite-roll zone check directly by calling internal methods with a known cast target position, so that I can verify in-zone and out-of-zone behavior without a live camera cast or timers.
2. As a developer, I want to verify the projectile arc math (launch velocity solve) in isolation, so that I can confirm the bobber lands exactly on the target position regardless of distance or flight time.
3. As a developer, I want to verify occupancy locking and unlocking by calling internal methods directly, so that I don't need a live network connection or a real timer firing to confirm a zone stays or doesn't stay protected.
4. As a developer, I want to verify that a disconnecting player's occupancy is cleared, so that a dropped connection can never permanently strand a zone.

## Implementation Decisions

### Decision 1: Cast Becomes a Solved Projectile Arc

Casting no longer places the bobber at the target position immediately. It computes a launch velocity (closed-form solve from start position, target position, flight time, and gravity) from the rod tip toward the target, and the bobber's position each frame during the flight is computed from that velocity and elapsed time. Two new tunables control this: flight duration and gravity strength. This applies identically to local and remote-rendered players, so teammates see the same arc.

### Decision 2: Fishing Zones Are Circles Owned by a New ZoneManager

A fishing zone is a position (water-surface center) and a fixed radius (radius does not vary between zones or reshuffles). A new ZoneManager node, sibling to the existing danger and quota managers, owns the pool of 2-3 zones and is host-authoritative — it mutates zone state and broadcasts the full zone list to clients, following the same pattern already used by the danger system's state sync.

### Decision 3: Zone Check Happens at Bite Roll, Not at Cast

Casting is never blocked by zone position. The zone check happens at the moment the bobber lands (bite-timer-eligible instant): the target position is checked against all current zones. If outside every zone, the mechanic never enters the bite state — it plays dead-zone feedback and returns to idle after the same delay a real bite would have taken. If inside a zone, bite rolls exactly as it does today.

### Decision 4: Zone Lookup Returns an Index, Not Just a Boolean

The zone check returns the index of the matching zone (or a sentinel for \"no zone\"), not just true/false, because occupancy tracking (Decision 5) needs to know which zone was entered. If a cast's radius genuinely overlaps two zones, the first match wins — in practice this is rare given the minimum-distance placement rule (Decision 7).

### Decision 5: Per-Zone Occupancy Locking, Count-Based

The fishing mechanic reports entering a zone (the instant the bobber lands inside one) and leaving it (on catch, escape, or dead-zone timeout) to ZoneManager. Each zone tracks an occupant count, incremented on entry and decremented on exit. A zone with a count greater than zero is excluded from reshuffling — locked in place — regardless of how many players are simultaneously occupying it. The zone only becomes eligible for reshuffling again once its count returns to zero. This is a per-zone lock, not a global freeze: other zones with no occupants continue to reshuffle normally even while one zone is locked.

### Decision 6: Unlocked Zones Rejoin the Normal Schedule, No Forced Re-Roll

When a zone's occupant count returns to zero, it does not immediately reshuffle. It simply becomes eligible again the next time the shared reshuffle timer fires, exactly like any other unoccupied zone. This avoids a second, special-case reshuffle trigger and avoids incentivizing players to bait teammates away from a zone to force an instant move.

### Decision 7: Randomized Reshuffle Timer, With Placement Retry Logic

ZoneManager runs a single shared reshuffle timer on a randomized interval (min/max range, following the same pattern as the danger system's respawn interval). On each firing, every currently-unoccupied zone is re-rolled to a new random position. Placement uses a retry-and-reject loop: a candidate position is checked against a minimum-distance-from-other-zones rule and a minimum-distance-from-the-water-boundary margin (so the full circle, including its fixed radius, stays inside the water plane); if a candidate fails either check, another is attempted, following the same reject-and-retry pattern already used by the danger system's shark spawn placement.

### Decision 8: Occupancy Reporting Is Trust-the-Client, With Disconnect Cleanup

Enter/leave zone reporting is a trust-the-client call (any connected peer reports its own occupancy state, the host accepts it), consistent with the project's existing trust-the-client pattern for catch reporting. To prevent a disconnecting player from permanently stranding a zone in a locked state, ZoneManager clears any occupancy held by a peer when that peer disconnects, using the same disconnect-cleanup path already used elsewhere for despawning players.

### Decision 9: Minimal Visual Zone Markers

Each zone is rendered with a simple, unshaded, translucent ring/circle marker on the water surface, synced from ZoneManager's broadcast position — no animation, no custom shader, consistent with the project's existing placeholder-geometry convention (e.g. the danger system's flat shark mesh). This is necessary specifically because zones now move: without a visible marker, a reshuffled zone would be an invisible moving target and players couldn't distinguish \"wrong spot\" from \"just unlucky.\"

### Decision 10: Restart Reset

ZoneManager gets a reset entry point, added to the round manager's existing per-system restart reset list (alongside the danger and fishing systems' own reset calls). On restart, all occupancy counts are cleared to zero as a safety net, and the reshuffle timer restarts fresh. Zone positions are not forced to re-roll on restart — they carry over from the previous round unless the timer happens to fire, consistent with the \"no special-case re-roll\" decision above.

### Decision 11: Dead-Zone Feedback Is a New, Fourth Feedback Type

The shipped Core Fishing Mechanic defines three feedback moments: catch success, catch failure/escape, and bite telegraph. This adds a fourth, parallel case — \"nothing's biting\" — triggered when a cast resolves outside every zone. It reuses the existing feedback-label infrastructure with distinct text and no success ding/flash, since nothing was caught or lost, just a wasted cast.

## Testing Decisions

Good tests here validate observable state and signal outcomes from direct method calls, bypassing timers, animation, camera raycasts, and live network connections — consistent with the existing pattern in the fishing mechanic and danger manager test suites.

Modules to test:

- Cast physics — given a start position, target position, flight time, and gravity, the velocity-solve produces a trajectory that lands exactly on the target at the end of the flight duration. No dependency on live timers.
- Zone lookup — the zone-index lookup returns the correct zone for a point inside its radius, and the \"no zone\" sentinel for a point outside every zone; a boundary case (distance exactly equal to radius) is treated as inside.
- Bite gating in-zone — the bite-timer-timeout handler with a target inside a zone transitions to the bite state exactly as today (existing behavior, re-verified after the change).
- Bite gating out-of-zone — the bite-timer-timeout handler with a target outside every zone does not transition to the bite state, transitions back to idle instead, and triggers dead-zone feedback exactly once.
- Occupancy locking — entering a zone increments its occupant count and excludes it from a simulated reshuffle pass; leaving decrements the count; a zone only becomes reshuffle-eligible again once its count returns to zero, even with multiple simultaneous occupants.
- Reshuffle placement — given existing zone positions, a newly placed zone respects both the minimum-distance-from-other-zones rule and the water-boundary margin; a zone excluded by occupancy is left untouched by a reshuffle pass.
- Disconnect cleanup — simulating a peer disconnect while it holds zone occupancy clears that occupancy, unlocking the zone.
- Restart reset — calling the reset entry point directly clears all occupancy counts and restarts the reshuffle timer, without forcing an immediate position change.

Prior art: follow the existing fishing mechanic and danger manager test patterns exactly — instantiate the relevant node directly, drive state via internal methods (bypassing timers), and assert on resulting state. No mocking framework, consistent with the rest of the project.

Explicitly not covered by automated tests, per existing project precedent: the visual arc's flight feel, the zone marker's rendering, and the dead-zone feedback label's animation — validated through manual playtesting.

## Out of Scope

- Zone editor or in-editor visual gizmo — zone placement is procedural-random within constraints, not hand-authored or user-editable.
- Variable per-zone bite rates or fish types — a zone is binary (bite possible / not possible), no weighting or fish-table concept yet.
- Variable zone radius, either per-zone or on reshuffle — radius is fixed for the whole feature.
- Host-computed occupancy verification — trust-the-client is accepted, consistent with the project's existing catch-reporting trust model; true anti-cheat is out of scope.
- Any change to reel mechanics, catch feedback, or the carryable-fish/storage-deposit flow — this feature only affects whether a bite occurs, upstream of everything after the bite state.
- Any change to the existing round-phase (fishing-active/round-active) gating — orthogonal; casting and bite-rolling both remain governed by that existing flag exactly as today.

## Further Notes

### Relationship to Shipped Core Fishing Mechanic Spec

This PRD does not edit or invalidate the shipped Core Fishing Mechanic spec. That document remains the historical record of what shipped. This PRD supersedes the behavior of its cast-placement and bite-timing decisions and adds a fourth feedback case, without modifying the original.

### Build Order Placement

This feature lands as step 3 in the Day → Shop Slice build order — after PlayerHealth and the Round Structure Rework's fishing-active/round-active split, and before Carryable Fish + Storage Deposit. Both this feature and Carryable Fish touch the fishing mechanic's cast/bite entry points, so landing this first avoids Carryable Fish rebasing around it.

### Dependency Note

No dependency on PlayerHealth, RoundManager's win/fail machinery, or Carryable Fish + Storage Deposit. Depends only on the shipped fishing mechanic, catch feedback system, and the existing danger system's spawn-placement and state-sync patterns, which this feature's ZoneManager deliberately mirrors rather than reinvents.
