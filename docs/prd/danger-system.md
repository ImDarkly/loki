**Feature ID:** DS-001
**Status:** Ready for Development
**Target Completion:** Week 3-4
**Owner:** Solo Developer
**Tech Stack:** Godot 4.6, GDScript

---

## Problem Statement

Fishing in silence is too safe. Players can ignore each other, focus purely on the reel mechanic, and grind quota without coordination or consequence. There is no shared threat that forces the team to change behavior mid-round, communicate under pressure, or accept painful tradeoffs between self-interest and team survival.

Current gap: once a fish bites, nothing can interrupt the player. The game has no danger, no escalating stakes, and no reason for players to speak during play.

---

## Solution

Introduce a shark that periodically approaches the player across the water surface. The shark functions as an escalating threat that the team can repel through voice — or ignore at the cost of quota.

The shark spawns at the edge of the water plane and swims directly toward the player. If the player yells (a keyboard key for MVP, voice amplitude post-MVP), the shark turns and retreats, then returns sooner and faster than before. If the player stays silent, the shark closes the distance and attacks: three caught fish are deducted from the team quota and any fish currently on the line escapes immediately.

Each yell that drives the shark away escalates its aggression. Swim speed increases and the cooldown before its next approach shortens. A successful attack resets escalation entirely, giving the team a moment of relief before the cycle restarts.

The system is built around a single core tension: yelling saves the line but accelerates the threat; silence loses quota but resets the pressure clock.

---

## User Stories

### Seeing the Shark Approach

1. As a **player**, I want to **see a shark fin moving across the water toward me**, so that **I immediately understand a threat is incoming and have time to decide what to do.**
2. As a **player**, I want to **see the shark approaching from the water boundary**, so that **the direction of the threat is spatially legible and not teleporting from nowhere.**
3. As a **player**, I want to **see the shark's distance close over roughly 3-5 seconds**, so that **I have a meaningful window to react rather than an instant penalty.**
4. As a **player**, I want to **recognize the shark's distinctive dorsal-fin silhouette at the water surface**, so that **I never mistake it for ambient scenery.**

### The Telegraph Window

1. As a **player**, I want to **have time to decide whether to yell or stay quiet before the shark attacks**, so that **the mechanic rewards awareness and creates genuine decision pressure.**
2. As a **player**, I want to **experience a moment of tension as the shark closes distance**, so that **the emotional arc of each approach feels meaningful.**
3. As a **player**, I want the **telegraph window to be consistent in feel**, so that **I can learn the threat rhythm and make informed decisions rather than guessing.**
4. As a **player**, I want the **telegraph window to shorten as escalation increases** (the shark moves faster), so that **the pressure of repeated yells is felt directly in reaction time.**

### Yelling to Repel the Shark

1. As a **player**, I want to **press a key to yell and drive the shark away mid-approach**, so that **I have active agency over the threat and can protect my fishing line.**
2. As a **player**, I want to **see the shark turn and retreat toward the water boundary immediately when I yell**, so that **my action has clear, immediate visual confirmation.**
3. As a **player**, I want to **see the shark despawn after it exits the water boundary**, so that **the scene is clean and I know the immediate threat is resolved.**
4. As a **player**, I want to **understand that yelling will bring the shark back sooner and faster**, so that **the tradeoff of using my voice is clear and intentional.**
5. As a **player**, I want to **be able to yell at any point during the shark's approach**, so that **I am not punished for reacting quickly or late within the window.**

### Fish Fleeing Mid-Reel

1. As a **player**, I want to **see my fish escape immediately if the shark attacks while I am reeling**, so that **the shark's attack has a direct, visceral cost beyond just quota numbers.**
2. As a **player**, I want to **understand that an attack while reeling loses the hooked fish but does not additionally penalize quota** (only already-caught fish are deducted), so that **the failure modes are distinguishable and fair.**
3. As a **player**, I want to **be returned to an idle fishing state after a fish flees due to a shark attack**, so that **I can resume fishing without manual intervention.**
4. As a **player**, I want to **be able to yell to prevent the fish-fleeing outcome**, so that **communication directly protects my immediate fishing activity.**

### Shark Returning Faster

1. As a **player**, I want to **feel the shark return noticeably sooner after each yell**, so that **the escalation is experiential, not just a hidden number changing.**
2. As a **player**, I want to **feel the shark moving visibly faster on its next approach**, so that **each yell I use tightens the reaction window for the next.**
3. As a **player**, I want to **experience escalation across multiple events in a single round**, so that **the tension builds continuously rather than resetting each time.**
4. As a **player**, I want to **understand that there is a floor to the return delay and a ceiling to swim speed**, so that **the threat is intense but never physically impossible to respond to.**

### Accepting the Quota Penalty

1. As a **player**, I want to **understand clearly when I have been attacked** (quota drops by 3), so that **I can assess the damage and adjust my strategy.**
2. As a **player**, I want to **see the quota reflect the penalty immediately**, so that **the consequence is legible without needing to count manually.**
3. As a **player**, I want to **accept a quiet attack as a valid strategic choice** (save voice, absorb quota loss), so that **there is no single correct answer and player agency is preserved.**
4. As a **player**, I want to **know that quota cannot go below zero**, so that **a late-round attack cannot create absurd negative states.**
5. As a **player**, I want to **know that accepting an attack fully resets escalation**, so that **absorbing the penalty has a tangible long-term benefit.**

### Escalation Reset

1. As a **player**, I want to **experience a noticeable calm after a shark attack lands**, so that **the escalation reset is felt as relief, not just a silent internal state change.**
2. As a **player**, I want to **see the next shark spawn on the full initial timer after an attack**, so that **accepting the hit buys real time before the next threat.**
3. As a **player**, I want to **understand that yelling many times consecutively creates its own danger** (escalation), so that **sustained shouting is not a free strategy.**

### Multiple Events Per Round

1. As a **player**, I want to **experience the shark appearing multiple times across a 15-minute round**, so that **the danger system is a recurring presence, not a one-time event.**
2. As a **player**, I want to **feel that each shark appearance has its own arc** (approach, decision, resolution), so that **the loop stays engaging across repetition.**
3. As a **player**, I want to **face different escalation levels across the round depending on my choices**, so that **no two rounds feel mechanically identical.**
4. As a **player**, I want to **coordinate with teammates about whether to yell**, so that **the danger system creates genuine communication moments during play.**

### Solo Testing Without Voice Chat

1. As a **developer**, I want to **test the full shark lifecycle using a keyboard key for yelling**, so that **I can validate all states without needing voice chat infrastructure.**
2. As a **developer**, I want to **verify escalation behavior across multiple consecutive shark events solo**, so that **I can tune speed and delay multipliers before playtesting with others.**
3. As a **developer**, I want to **observe the state machine transition through all states** (INACTIVE, APPROACHING, ATTACKING, RETREATING, WAITING) **in a single session**, so that **I can catch edge cases before multiplayer introduces noise.**
4. As a **developer**, I want to **confirm quota penalty fires correctly and FishingMechanic receives fish_fled**, so that **the signal wiring works end-to-end without a real team.**
5. As a **developer**, I want to **tune all export variables in the Godot Inspector without touching code**, so that **difficulty iteration is fast during solo playtest sessions.**

---

## Implementation Decisions

### Scene Architecture

DangerManager is a child of the main scene node and a sibling of the Player node. It is not parented to Player because in multiplayer, one DangerManager governs the shared game world and affects all players simultaneously. Parenting it to Player would replicate the node per player in networked scenes, which is incorrect.

The shark itself is instantiated as a child of DangerManager when spawned and freed when it exits the water boundary.

---

### Yell Detection

The player owns an `is_yelling` boolean. In the MVP, this is set by a keyboard key press handled in the player's input function. DangerManager reads this property each frame during the APPROACHING state.

When GD-Sync voice chat is integrated later, only the player's setter changes — the internal logic swaps from keyboard input to amplitude threshold detection. DangerManager reads the same `is_yelling` property and never changes. This seam is intentional and must not be violated.

---

### Signal Wiring

DangerManager emits two signals: `fish_fled` and `quota_penalty`. The main scene's `_ready` function connects `fish_fled` to the FishingMechanic, and `quota_penalty` to whatever owns the quota counter. DangerManager has no reference to FishingMechanic internals. This keeps coupling one-directional: DangerManager announces events; consumers decide what to do.

---

### State Machine

The shark lifecycle follows this state machine:
INACTIVE    → (spawn timer fires)             → APPROACHING
APPROACHING → (player.is_yelling == true)     → RETREATING
APPROACHING → (distance < attack_range)       → ATTACKING
ATTACKING   →                                 → RETREATING  [escalation resets, new spawn timer]
RETREATING  → (exits water boundary)          → WAITING
WAITING     → (return_delay expires)          → APPROACHING

INACTIVE is the state before the first spawn. The initial spawn is gated by `initial_spawn_delay` to give players time to settle into the round. After that first spawn, the system cycles between APPROACHING, RETREATING, WAITING, and back — never returning to INACTIVE.

---

### Shark Spawn Position

The spawn point is chosen randomly on the perimeter of the 50×50 water rectangle centered at (0, 0, -7). The shark is positioned at y=0 (water surface). After spawning, the shark moves straight toward the player's XZ position each frame via `move_toward`, recalculated every frame so it tracks player movement.

---

### Movement and Attack Trigger

Movement is translation-based, not physics-based. The shark moves toward the player (APPROACHING) or toward its spawn point (RETREATING) each physics frame. Speed is controlled by `swim_speed`, which escalates per yell.

Attack fires when the shark's distance to the player drops below `attack_range`. This is a distance check, not a timer. The initial `swim_speed` is tuned so the crossing from boundary to attack range takes approximately 3-5 seconds — this swim time is the telegraph window.

---

### Yell Response and Escalation

When the player yells during APPROACHING, the shark immediately transitions to RETREATING. Before transitioning, escalation is applied:

- `swim_speed` is multiplied by `speed_multiplier` (default 1.3), floored at `min_swim_speed`
- `return_delay` is multiplied by `delay_multiplier` (default 0.7), floored at `min_return_delay`

These escalation values persist on DangerManager across shark instances for the round. They reset only when a successful attack lands.

---

### Attack Consequence

When the shark attacks (APPROACHING → ATTACKING):

1. DangerManager emits `fish_fled`. FishingMechanic receives this and triggers its existing reel failure path immediately. If no reel is active, the signal fires but has no effect on FishingMechanic state.
2. DangerManager emits `quota_penalty` with a value of 3. The quota owner deducts from the team quota, clamped to a floor of 0.

Escalation then resets to initial values. A new spawn timer starts using a random interval between `respawn_interval_min` and `respawn_interval_max`.

---

### Tunable Exports

All difficulty parameters are exported variables on DangerManager, editable in the Godot Inspector without touching code:

| Export | Default | Description |
| --- | --- | --- |
| `initial_spawn_delay` | 60.0 s | Delay before first shark appears |
| `respawn_interval_min` | 180.0 s | Minimum interval after an attack reset |
| `respawn_interval_max` | 300.0 s | Maximum interval after an attack reset |
| `initial_swim_speed` | 3.0 | Starting approach and retreat speed |
| `attack_range` | 2.0 | Distance threshold at which attack fires |
| `initial_return_delay` | 4.0 s | Starting WAITING duration after a yell |
| `speed_multiplier` | 1.3 | Swim speed multiplier applied per yell |
| `delay_multiplier` | 0.7 | Return delay multiplier applied per yell |
| `min_swim_speed` | 8.0 | Floor on swim speed escalation |
| `min_return_delay` | 0.5 s | Floor on return delay escalation |

---

### Shark Mesh

The shark is a procedurally generated flat triangular prism in gray, shaped to suggest a dorsal fin, positioned at y=0. No art assets or imported meshes are required. This keeps the feature shippable without an art pipeline and is replaced by a real model post-MVP.

---

## Testing Decisions

### What Makes a Good Test

A good test validates observable state transitions and signal emissions — not internal variable manipulation or visual rendering. For the danger system:

- **Good:** "When `is_yelling` is true during APPROACHING, state transitions to RETREATING and `swim_speed` is multiplied by `speed_multiplier`." Observable output from a controlled input.
- **Bad:** "The shark mesh vertex positions are correct." Rendering detail, brittle to geometry changes, carries no behavioral signal.
- **Good:** "After an attack, escalation values return to their initial values." Verifiable reset with direct gameplay consequence.
- **Bad:** "DangerManager calls `move_toward` exactly N times per frame." Tests implementation, not behavior.

Tests should set up minimal state (bypassing timers by calling internal transition methods directly), apply a single stimulus, and assert the resulting state and any emitted signals.

### Modules Under Test

**Seam 1 — DangerManager state machine (new test file)**

The state machine is the primary behavioral unit and should be tested in isolation. Tests should cover:

- INACTIVE → APPROACHING when spawn timer fires
- APPROACHING → RETREATING when `is_yelling` is true; escalation values updated correctly
- APPROACHING → ATTACKING when distance drops below `attack_range`; `fish_fled` and `quota_penalty` signals emitted
- ATTACKING → RETREATING immediately; escalation reset to initial values
- RETREATING → WAITING when shark exits water boundary
- WAITING → APPROACHING when `return_delay` expires
- Escalation floor clamping: repeated yells do not push `swim_speed` past `min_swim_speed` or `return_delay` below `min_return_delay`
- Escalation resets fully after a successful attack

**Seam 2 — FishingMechanic + fish_fled (one new test in existing test file)**

One test added to the existing fishing mechanic test file verifies that when `fish_fled` is received during the REELING state, the mechanic transitions to its reel failure path (state = IDLE, quota unchanged, `reel_failure` emitted). No other danger-system tests belong in the fishing mechanic test file.

### Prior Art

The existing fishing mechanic test file is the reference for GUT patterns in this project. Key conventions to match:

- `extends GutTest`
- Scene loaded and instantiated via `autofree` in `before_each`
- State asserted by comparing `current_state` to integer enum values with a descriptive string argument
- Timers stopped manually before triggering timeout callbacks to avoid frame-dependent waits
- No mocking framework — drive state by calling internal entry methods directly

New test files should follow this structure exactly.

---

## Out of Scope

- **Voice amplitude detection** — GD-Sync integration is post-MVP. The `is_yelling` property setter is the designated swap point; no other code changes when this ships.
- **Multiple simultaneous sharks** — one shark at a time is sufficient to create pressure for MVP.
- **Multiple danger types** — storms, krakens, and other hazards are post-MVP.
- **Shark animations and art assets** — the procedural dorsal fin mesh is the entire art requirement for MVP.
- **HUD directional indicator** — no on-screen arrow pointing at the shark. Players must watch the water.
- **Per-player proximity radius** — in multiplayer, the single DangerManager affects the shared world. Per-player threat zones are a post-MVP multiplayer design problem.
- **Danger events tied to the game timer** — no scheduling logic that reacts to time remaining. Timing is purely interval-based.

---

## Further Notes

### Escalation Feel

The default multipliers (speed 1.3×, delay 0.7×) are starting points. At those values, three consecutive yells produce a swim speed of roughly 5.1 and a return delay of roughly 2.0 seconds — meaningfully tighter but not yet floored. The floors exist to prevent the shark from becoming a teleporting instant-kill at high escalation. Playtest the multipliers first; adjust floors only if players hit them regularly.

### Quota Floor

Quota is clamped at 0. A late-round attack on a team with fewer than 3 caught fish does not create a negative quota. This is handled at the quota owner level, not inside DangerManager. DangerManager always emits `quota_penalty` with a fixed value of 3; the consumer applies the clamp.

### MVP Keyboard Yell Key

The yell key is a configurable input action and must not conflict with any existing fishing inputs. The exact key is a tuning decision left to playtesting; the architecture does not depend on which key it is.

### Multiplayer Forward-Compatibility

DangerManager is positioned as a scene sibling of Player today. In a networked session, only the authoritative peer should run DangerManager's state logic. The signal-based decoupling means adding network authority checks later requires changes only inside DangerManager — no consumer code changes.
