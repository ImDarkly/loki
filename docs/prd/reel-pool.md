**Feature ID:** RP-001

**Status:** Ready for Development — resolved via grill-me session

**Owner:** Solo Developer

**Tech Stack:** Godot 4.6, GDScript

---

## Problem Statement

The current bite-resolution step is a single button press inside a 2.5-second window (`FishingMechanic._process`, BITE state, `_bite_time >= 2.5` hard timeout). This is the thinnest possible interaction in the core loop and was flagged directly against friendslop-genre research as the highest-risk repetition antipattern (6 of 11 researched games cite "repetitive" as their primary weakness — see Friendslop Research). It also currently generates zero visible chaos for teammates — a bite resolves silently and instantly from outside the catching player's own screen.

Any fix has to fit inside a genuinely tight constraint: the shark's approach-to-attack window is ~5 seconds. A mechanic that pulls a player's attention too far inward (multi-button states, timing precision, anything requiring sustained visual focus away from the world) actively competes with the exact ambient danger-awareness the rest of the game's systems are built around.

## Solution

Bite resolution becomes two stages. **Stage 1 is unchanged**: the existing click-to-hook reaction window stays exactly as it is today. **Stage 2 is new**: on a successful hook, the player enters a 2–8 second scroll-driven reel tug-of-war instead of an instant catch.

The fish stays fixed at its hooked position (the existing `cast_target_position` / bobber location) — only the player's own character is what moves. Scroll input continuously reels the player closer to the fish; while not actively reeling, a pull continuously (and visibly, to teammates, since it rides existing position sync) drags the player toward the fish/water. Reaching the fish (distance ≈ 0) is the catch. There is no separate progress value to track — distance-to-fish *is* the progress bar.

Two distinct loss paths exist, deliberately kept separate rather than merged into one system:

1. **Passive drift** — the ambient pull, if never countered, can eventually walk a player into the water on its own. This is the mild, low-drama outcome of simply not paying attention.
2. **Escape-launch** — if scroll rate drops below a floor for a sustained duration (~1.5–2 seconds), the fish breaks free and fires a single strong one-shot impulse launching the player hard in the fish's escape direction — a real, chaotic "yeet," reusing the existing rod-pull knockback code path, capable of reaching real hazards (water edge, shark range) rather than being purely cosmetic. This requires a visible/audible telegraph (rising pitch, rod-bend intensity) in the second or two before it fires, so a loss reads as earned, not arbitrary — directly avoiding the exact "unfair random hazard" antipattern Lethal Company is criticized for in genre research.

A visibly swimming fish *before* the bite (decorative, client-local, no network authority, no gameplay stakes) is a related but separate visual layer — the fish is only fixed-in-place once the fight itself (Stage 2) begins.

## User Stories

1. As a player, I want reeling in a fish to be an active, ongoing effort, not a single button press, so that catching a fish feels like a real moment instead of a formality.
2. As a player, I want to feel a real pull toward the fish while I'm fighting it, so that the struggle is physical, not just a number on a UI.
3. As a player, I want scrolling my mouse wheel to be the way I fight back against that pull, so that the input matches the fantasy of cranking a real reel.
4. As a player, I want to see a teammate visibly get dragged around while they're mid-catch, so that I can react to their situation from across the map without needing to see their screen.
5. As a player, I want a clear warning before a fish is about to escape, so that a loss feels like my mistake, not bad luck.
6. As a player, I want losing a fight to sometimes throw me somewhere dangerous, so that a bad catch has real, chaotic stakes beyond just losing the fish.
7. As a player, I want the whole fight to stay short (a few seconds), so that it never becomes the main event of a round — it should fit inside the game's danger pacing, not compete with it.
8. As a developer, I want the fish's position during the fight to be static and player-authoritative-free, so that this feature adds no new network-sync surface beyond what `Player._sync_transform` already provides.

## Implementation Decisions

### Decision 1: Two-Stage BITE State, Stage 1 Untouched

The existing click-to-hook reaction window inside `FishingMechanic`'s BITE state is not modified. A successful hook transitions into a new internal sub-behavior (not a new top-level `State` enum value — BITE covers both stages) that drives the tug-of-war. Remote clients continue to see only the existing `current_state` sync (BITE → SUCCESS/IDLE); no new state needs to be added to the synced enum.

### Decision 2: Fish Position Is Static During the Fight

The fish remains fixed at `cast_target_position` for the duration of Stage 2. Only the player's `CharacterBody3D` position moves. This keeps "distance to fish" a single, simple value (distance from a moving player to a static point) rather than requiring two synchronized moving entities. The separately-planned pre-bite swimming fish (decorative AI, visible before the hook) is unaffected by and unrelated to this decision — it stops moving the instant the fight begins.

### Decision 3: Continuous Pull Overrides Normal Movement, Not Additive

During the fight, `Player._physics_process`'s existing WASD-driven velocity block is gated off (new branch at the top of the function, same shape as the existing `PlayerState.SPECTATE` early-return), and a pull vector toward the fish is applied instead. An additive model (pull layered on top of normal WASD) was explicitly rejected: a player could simply hold forward and cancel the pull outright, defeating the mechanic entirely. Camera/look input is untouched either way.

### Decision 4: Pull Strength Scales With Distance-to-Fish; Scroll Reduces Distance

Pull strength is a function of current distance-to-fish (closer = less pull; this is tunable, not necessarily linear). Scroll input directly reduces distance-to-fish. This means reel "progress" and pull "intensity" are never two independently-tracked values — they're the same underlying number, viewed from two directions. Catch condition: distance-to-fish reaches (approximately) zero.

### Decision 5: Two Independent Loss Paths, Not Merged

**Passive drift** (Decision 3's continuous pull, if never sufficiently countered by scrolling) can on its own eventually walk a player into the water — this is the mild, ambient outcome and depends on the (separately planned, not yet built — see Dependency Note) Water Float system to be a non-punishing landing rather than a hard fail.

**Escape-launch** is a distinct, discrete trigger: if scroll rate stays under a tunable floor continuously for roughly 1.5–2 seconds, the fish escapes and fires a single one-shot velocity impulse at the player, reusing the existing `PlayerRodTarget`-style knockback code path rather than introducing new physics. This was deliberately kept separate from passive drift rather than merged into one "you lose" condition, specifically so the game has both a low-drama failure mode (didn't notice, drifted a bit) and a high-drama one (blew a critical moment, got launched) — collapsing them into a single trigger was considered and rejected during design, since it would mean the game only ever has one, less legible, way to fail.

### Decision 6: Mandatory Pre-Escape Telegraph

The under-floor duration timer that drives Decision 5's escape-launch must also drive a rising audio/visual telegraph (pitch increase, rod-bend intensity) in the second or two before the trigger fires. This is a hard requirement, not a nice-to-have: research into comparable genre titles identified untelegraphed sudden-failure moments (e.g. Lethal Company's randomly-placed instant-death hazards) as a specific, named antipattern that reads as "unfair" rather than "a real mistake." No new tracked value is needed — the telegraph is driven off the same timer that triggers the escape itself.

### Decision 7: Old Hard Timeout Is Replaced, Not Left Running

The existing `_bite_time >= 2.5` unconditional force-fail is removed entirely and replaced by Decision 5's under-floor timer. Leaving the old timeout running alongside the new tug-of-war would force-fail mid-fight regardless of player performance, which would silently break the new mechanic rather than coexist with it.

### Decision 8: No RMB / `interact` Conflict

Because reeling is entirely scroll-wheel-driven, this feature does not touch right-click at all. The `interact` action collision that an earlier (rejected) click-based reel design would have required guarding against does not apply here and needs no gating code.

## Testing Decisions

Consistent with this project's existing precedent of testing state-transition logic directly (bypassing timers, camera input, and hardware-dependent behavior — see `test_fishing_mechanic.gd`, `test_danger_manager.gd`):

- **Covered:** distance-to-fish calculation given a simulated scroll input; catch triggers correctly when distance reaches the zero threshold; escape triggers correctly once the under-floor duration timer exceeds its threshold, and does not trigger prematurely; the telegraph-driving timer value is readable/inspectable before the escape fires.
- **Not covered by automated tests, per existing project precedent:** actual mouse-wheel input feel/hardware behavior, the visual pull/drag animation itself, Water Float's catch behavior (a separate, not-yet-built system this feature depends on), and the escape-launch's physical trajectory feel — validated through manual playtesting, consistent with how this project already excludes rendering and physics-feel from its test suite.

## Out of Scope

- **Pre-bite swimming fish AI** — a related but separate visual/atmosphere feature (decorative, client-local, no gameplay stakes). Not blocking this PRD; can land before, after, or independently of it.
- **Per-fish-type resistance curves** — explicitly considered and rejected during design as unnecessary content-authoring debt; any future fish variety should reuse a single generic difficulty stat, not per-species tuning.
- **RESIST/TIRED two-phase button-based reeling** — an earlier direction explored and rejected in favor of continuous scroll, specifically because state-switching during a fight was judged to cost too much attention relative to the game's short danger-reaction windows.
- **Fish rarity/variety layer, solo-mode balance decisions** — both separately identified as needed improvements, deliberately parked outside this PRD's scope to avoid scope creep.
- **Zone-driven pull-direction bias (pulling toward hazards based on ZoneManager data)** — a possible future enhancement, not required for this feature to function.

## Further Notes

### Dependency Note

The "passive drift ends in water" loss path (Decision 5) assumes the Water Float system described in the Day → Shop Slice (Pre-Demo) PRD exists so that entering water is a non-punishing landing rather than an undefined state. If Water Float is not yet built when this feature is implemented, passive drift should either be temporarily disabled (keep only the escape-launch loss path) or explicitly scoped to not require water entry to feel complete.

### Design Origin

This PRD was resolved through an extended grill-me-style interview, starting from two Ideas-list entries ("reeling fish pulls you slowly in fish direction" / "if you lose fish it pulls you fast in its direction") and a parallel friendslop-genre research pass that flagged the previous instant-catch mechanic as a repetition-risk antipattern. Several alternative input schemes (flat click-mash, LMB-mash/RMB-hold two-phase, cycling multi-phase fights) were explicitly compared and rejected in favor of continuous scroll specifically for its combination of low learnability cost (fits inside the ~5-second shark danger window) and its ability to generate teammate-visible chaos through real character movement rather than private UI feedback.

### Relationship to Full Playable Cycle (RSK-001)

This feature directly supersedes Full Playable Cycle's Decision 11 ("Bite Resolution — Direct BITE → SUCCESS on Button Press"), which introduced the single-click instant-catch this PRD replaces. That document remains the historical record of what shipped previously; this PRD does not edit it directly.
