**Feature ID:** DSS-001

**Status:** Ready for Development

**Owner:** Solo Developer

**Tech Stack:** Godot 4.6, GDScript, ENet

---

## Problem Statement

The game currently has a working Round Lifecycle (timer, shared quota, win/fail, restart) but the actual moment-to-moment day gameplay it wraps is thin: a caught fish is auto-reported to the shared quota the instant the reel succeeds, there is no physical storage to protect, the shark's attack is an abstract `quota_penalty` with no effect on the player themselves, and there is no player health, death, or shop of any kind. None of the chaos mechanics the team wants to prototype — carrying a fish somewhere risky, getting knocked into water, slapping a friend with a fish, rescuing someone with a rod — exist yet.

Building the full Night (monster, barrier defense, jump-scares) on top of this thin day loop is risky: if the day mechanics aren't already fun and legible on their own, adding Night won't fix that, and time will be lost tuning horror pacing before the core is proven. The team needs a small, playable slice — Day into Shop, no Night — to playtest the day mechanics and the shop loop in isolation first.

## Solution

Rework the day loop so a caught fish becomes a carryable object the player must walk to a physical storage container and manually deposit — creating a vulnerability window the shark can punish. Give players a health pool that the shark's bite damages directly (replacing the abstract quota penalty), with death dropping the player into a simple spectate state until the next round. Add three chaos mechanics on top: a player-targetable rod pull (cast on a teammate, hold to reel them toward you, no minigame, works anywhere), a fish-slap that pushes a nearby player, and water buoyancy so anyone who ends up in the water floats instead of sinking. Wire the existing yell-detection into the fishing mechanic so yelling scares nearby fish away, as originally designed but never connected.

When RoundManager's timer runs out, stop the fishing mechanic from accepting new casts (no more catches possible) but leave everything else — movement, the shark, slapping, rod-pulling — live, so players keep messing around instead of being frozen. A shop hut on the island becomes interactable: walking up and interacting opens a panel showing the team's stored fish, a Sell button that converts them to coins, and a couple of permanent upgrades to buy. The host's "Start Next Round" restarts the round exactly as Round Lifecycle already does today, with the addition that coins and purchased upgrades are explicitly never reset.

## User Stories

### Carrying and Storing Fish

1. As a player, I want a fish I just caught to appear held in my hands, so that catching feels physical rather than instant and abstract.
2. As a player, I want to walk to the storage container and interact to deposit my held fish, so that I have to make a deliberate trip rather than banking catches automatically.
3. As a player, I want my held fish to be at risk while I'm carrying it, so that the shark and my teammates' antics have something real to threaten.
4. As a player, I want to lose my currently-held fish if I take damage while carrying it, so that getting bitten or slapped mid-carry has a real cost.
5. As a player, I want to only be able to carry one fish at a time, so that the carry step stays a deliberate, repeated action rather than a one-time stockpiling trip.

### Player Health and Death

1. As a player, I want a visible health value, so that I understand how much punishment I can take before dying.
2. As a player, I want the shark's bite to directly damage my health instead of costing the team fish, so that the shark threatens me personally, not an abstract team number.
3. As a player, I want to die when my health reaches zero, so that the shark threat has real stakes.
4. As a player, I want to become a spectator when I die, unable to move or interact, so that I'm not confused about my state after dying.
5. As a player, I want to be able to keep watching my teammates play after I die, so that I'm not just staring at a black screen until the round restarts.
6. As a player, I want my health to fully restore when a new round starts, so that dying doesn't carry a permanent penalty beyond the current round.

### Shark Rework

1. As a player, I want the shark to keep roaming and attacking even after the fishing timer runs out, so that day still feels a little dangerous during the free-roam period, not fully safe.
2. As a developer, I want the shark's bite damage to be a tunable export variable, so that I can rebalance how many bites it takes to kill a player.

### Fish-Slap

1. As a player, I want to slap a nearby teammate with my fish, so that I have a simple, funny way to mess with people.
2. As a player, I want a slap to physically push the target away, so that it has a visible, satisfying effect.
3. As a player, I want a slap to be able to knock someone into the water if they're close enough to the edge, so that slapping chains into other systems (floating, rescue) rather than being an isolated joke.

### Player-Targeted Rod Pull

1. As a player, I want to cast my rod at a teammate instead of a fish, so that I can grab and pull them.
2. As a player, I want holding the reel input to pull my target steadily toward me with no timing challenge involved, so that rescuing someone is simple and readable under pressure.
3. As a player, I want to be able to rod-pull a teammate whether they're on land or in the water, so that it's one general-purpose tool, not a water-only rescue mechanic.
4. As a player, I want releasing the reel input to stop the pull immediately, so that I have full control over when to let go.

### Water Float

1. As a player, I want to float on the water's surface if I end up in it, whether I jumped, fell, or got slapped in, so that entering water is never an instant fail state.
2. As a player, I want floating to feel distinct from moving on land, so that being in the water is legible at a glance.
3. As a player, I want to be able to get out of the water under my own power, so that I'm not always dependent on a teammate's rod-pull to recover.

### Timer-Only Round End (No Night Yet)

1. As a player, I want fishing to stop being possible once the round timer runs out, so that there's a clear signal the "catching" part of the round is over.
2. As a player, I want to still be able to move, slap, rod-pull, and get bitten by the shark after the timer runs out, so that the world doesn't just freeze while I wait to go to the shop.
3. As a developer, I want the fishing-stops behavior to be decoupled from the shark's own activity, so that I can playtest day mechanics without Night existing yet, without the shark going inert at the same moment fishing does.

### Shop Location and Interaction

1. As a player, I want the shop to be a physical hut I walk up to, not a menu that appears over my screen automatically, so that it feels like part of the world rather than a pause menu.
2. As a player, I want to interact with the shop to open its panel, so that I choose when to engage with it rather than being forced into it.
3. As a player, I want to keep playing around on the island (not be teleported or locked) once the timer ends, so that visiting the shop is my own choice and pace.

### Shop UI and Selling

1. As a player, I want to see our team's total stored fish when I open the shop, so that I know what we have to work with.
2. As a player, I want to sell our stored fish for coins, so that I have a currency to spend on upgrades.
3. As a player, I want to see our current coin total, so that I know what I can afford.

### Upgrades and Persistence

1. As a player, I want to spend coins on a couple of permanent upgrades (e.g. more health, faster rod-pull), so that playing well has a lasting payoff.
2. As a player, I want purchased upgrades to still be active in the next round, so that spending coins feels meaningful rather than wasted.
3. As the host, I want the same "Start Next Round" control that already exists today, so that restarting doesn't need a second, separate system.
4. As a player, I want our coins and upgrades to be the only things NOT reset when the round restarts, so that progress persists correctly while the round itself starts clean.

### Solo/Small-Group Testing

1. As a developer, I want to trigger a player's death and health damage directly by calling internal methods, so that I can verify state without needing a live shark encounter.
2. As a developer, I want to verify the fishing-stops-but-shark-continues behavior independently, so that I can confirm the decoupling is correct without playing out a full round.
3. As a developer, I want to verify coin selling and upgrade persistence by calling internal methods directly, so that I don't need a live network connection to confirm correctness.

## Implementation Decisions

### Decision 1: New PlayerHealth Module

A new deep module, `PlayerHealth`, owns `max_health`, `current_health`, and exposes `take_damage(amount)`. It emits `health_changed(value)` and `died()` the instant `current_health` reaches zero, clamped at 0 (never negative). It has no dependency on any other system — DangerManager, FishSlap, and any future damage source all call `take_damage` the same way. On `died()`, the player enters a spectate state: movement, casting, slapping, and rod-pull input are all disabled, but the camera stays active so the player can keep watching the round. Death is cleared (health restored to max, spectate state cleared) as part of RoundManager's existing restart reset — this feature adds `PlayerHealth` to the reset list already established in Round Lifecycle's Decision 9.

### Decision 2: Shark Damages PlayerHealth Directly, Not Quota

DangerManager's `_trigger_attack()` no longer emits `quota_penalty`. Instead, it calls `take_damage(shark_bite_damage)` on the targeted player's `PlayerHealth`, where `shark_bite_damage` is a new tunable export on DangerManager. `fish_fled` (dropping the target's currently-held/reeling fish) is unaffected and still fires the same way. This is a direct behavioral change from the existing Danger System spec's team-quota-penalty design — the shark now threatens the individual it targets, not the shared team total.

### Decision 3: Shark Keeps Running Independent of round_active

DangerManager's existing `round_active` guard (added in Round Lifecycle) is removed for this slice. The shark's `_physics_process` and spawn/return timers run regardless of whether the round's fishing phase has ended. A new, separate boolean — `fishing_active` — is introduced specifically for gating `FishingMechanic`'s cast/reel input, decoupled from `round_active`. RoundManager's timer expiry sets `fishing_active = false` (not `round_active = false`); `round_active` and its associated win/fail/restart machinery are otherwise unchanged from the existing Round Lifecycle spec, minus the quota-win branch (Decision 4).

### Decision 4: RoundManager Drops the Quota-Win Branch

This slice has no win/fail condition — only a timer. RoundManager's existing `_on_quota_updated` early-win check and `quota_target` field are removed for this feature. The round always proceeds to its timer expiry, at which point `fishing_active` is set false (Decision 3) rather than the round ending in success or failure. There is no end screen shown at this point — the shop (Decision 8) is the only post-timer destination, and the round only truly "ends" and resets via the host's restart control, same mechanism as today.

### Decision 5: Carryable Fish and Storage Deposit — Superseded by a Standalone Spec

**This decision has been carved out into its own focused PRD, Carryable Fish + Storage Deposit (CFS-001), which supersedes the prose below with a more detailed interaction model (camera-forward raycast interact on a hardcoded storage box, not a proximity `Area3D`).** The original intent is preserved for historical context: on reel success, `FishingMechanic` no longer calls `_report_catch_to_host` directly; the player instead enters a carrying state (one fish at a time), and depositing at a storage point is what actually calls `report_catch(1)` on QuotaManager. Refer to CFS-001 for the authoritative implementation and testing decisions.

### Decision 6: PlayerRodTarget as a Separate Module From FishingMechanic

Rather than extending `FishingMechanic`'s fish-oriented state machine, player-targeting is its own small deep module, `PlayerRodTarget`: cast raycasts for a `Player` node instead of spawning a fish; holding the existing reel input moves the target's position toward the caster at a fixed rate every physics frame (`move_toward`, no meter, no success/fail); releasing the input stops the pull immediately. It has no shared state with `FishingMechanic` and works identically whether the target is on land or in water. It is never gated by `fishing_active` or `round_active` — it's available at all times, consistent with the "still be able to rod-pull" user stories.

### Decision 7: Fish-Slap and Water Float

Fish-slap is a new input action performing a short-range hit-check in front of the caster; on hit, it applies a push impulse to the target's velocity away from the caster. Water float is handled by a new `Area3D` matching the existing water plane's bounds: on a player entering, their physics switches to a floating mode (reduced/zeroed gravity, gentle bob, drift, still player-movable); on exit, normal physics resumes. Neither system depends on round or fishing state — both work at any time, day or night, in or out of a round.

### Decision 8: Shop Hut, Interaction, and Selling

A static shop hut model with an `Area3D` interaction zone is placed on the island (per current location design). Interacting opens a `ShopUI` panel showing the team's current stored fish count (`QuotaManager.shared_quota`), a "Sell All" button that converts the full stored count to coins at a fixed rate via a new `CoinManager` node (host-authoritative, same broadcast pattern as `QuotaManager`), the resulting coin total, and 1-2 upgrade buttons (e.g. `+max_health`, `+rod-pull speed`) with coin costs. The panel's "Start Next Round" button is the same host-only restart control already established in Round Lifecycle Decision 8 — no second restart mechanism is introduced.

### Decision 9: Coins and Upgrades Are Explicitly Excluded From Restart Reset

Round Lifecycle's existing restart reset list (RoundManager, QuotaManager, DangerManager, FishingMechanic) is extended to include `PlayerHealth` (Decision 1) and `fishing_active` (Decision 3), but `CoinManager`'s coin total and any purchased upgrade flags are explicitly never touched by restart — they persist for the lifetime of the session, which is the entire point of the shop.

### Decision 10: Yelling Scares Fish (Wiring Only)

`VoiceChatManager.is_yelling` already exists and already works; nothing about it changes. This feature adds the missing connection: `FishingMechanic` listens for a yelling player within a fixed radius and, if any are yelling, cancels the current bite/flees the fish (mirrors the existing `on_fish_fled` cleanup path). This was always the design intent (per the MVP spec) but was never actually wired up in code.

## Testing Decisions

Good tests here validate observable state and signal outcomes from direct method calls, bypassing timers, animation, and live network connections — consistent with the existing pattern in `test_danger_manager.gd` and `test_fishing_mechanic.gd`.

Modules to test (deep, no live network required):

- **PlayerHealth** — `take_damage` reduces `current_health` correctly and clamps at 0; `died()` emits exactly once when health reaches 0; `health_changed` emits on every change; restoring to max_health and clearing spectate state work via direct method call.
- **CoinManager** — selling converts the given fish count to coins at the correct rate; spending on an upgrade deducts coins correctly and rejects a purchase if coins are insufficient; coins are unaffected by a simulated round restart.
- **StorageArea deposit** — depositing a carried fish calls `report_catch(1)` exactly once and clears the carried state; taking damage while carrying clears the carried fish without calling `report_catch`.
- **PlayerRodTarget** — given a target position and a held input, the target's position moves toward the caster by the expected amount per physics tick; releasing the input stops further movement.
- **DangerManager attack change** (one new test added to the existing `test_danger_manager.gd`, following the existing single-added-test pattern) — `_trigger_attack` calls `take_damage(shark_bite_damage)` on the targeted player instead of emitting `quota_penalty`.
- **RoundManager fishing_active decoupling** (new tests, replacing the removed quota-win tests) — timer expiry sets `fishing_active` false and leaves `round_active` untouched; DangerManager's `_physics_process` continues to run when `fishing_active` is false, confirming the two flags are independent.
- **FishingMechanic yell-flee** (one new test added to the existing `test_fishing_mechanic.gd`) — given a yelling player in range during BITE or WAITING state, the fish flees the same way `on_fish_fled` already handles it.

Explicitly not covered by automated tests, per existing precedent: fish-slap's physics feel, water float's buoyancy feel, the shop hut's 3D interaction prompt, and the `@rpc` broadcast plumbing for any of the above — these are validated through manual multi-instance playtesting, consistent with how this project already excludes rendering and live-network plumbing from its test suite.

## Out of Scope

- **Night phase entirely** — no monster, no barrier-defense minigame, no jump-scares. This slice is Day → Shop only, explicitly to playtest day mechanics before Night is built.
- **Weapon system** — no scaring off the shark with a weapon; the shark is unaffected by anything except yelling triggering the existing danger-manager retreat-on-yell behavior already in place. (Yelling still only affects fish-fleeing per Decision 10 and the shark's existing yell-triggered retreat is untouched.)
- **Seagulls** — never built, not part of this slice.
- **Boat piloting and dusk dock-race** — dropped earlier in design discussion; this slice's map has no mobile boat.
- **Hoard-vs-sell choice** — the shop only offers "Sell All"; no partial selling or carrying fish forward between rounds.
- **Per-player catch breakdown or leaderboard** — not part of the shop UI for this slice.
- **Whether "Start Next Round" requires every player to have visited the shop first** — resolved by reusing the existing host-only restart control as-is (Decision 8); any player can view/sell/buy, but only the host's restart actually advances the round, exactly as today.

## Further Notes

### Publishing Note

Following the precedent set by the 4-Player Multiplayer and Round Lifecycle specs, this PRD is published to Notion under Project Loki's Specification section. This repository has no connected issue tracker, so Notion + `docs/prd/*.md` remains this project's equivalent publishing target.

### Dependency Note

This feature builds directly on top of the already-shipped Round Lifecycle, DangerManager, FishingMechanic, and QuotaManager. It should land after those remain stable, which they already are per the current codebase.

### Suggested Build Order

1. PlayerHealth module, tested in isolation, wired into DangerManager's attack (Decisions 1-2). **Shipped.**
2. RoundManager's fishing_active/round_active split, replacing the quota-win branch (Decisions 3-4) — implemented in full detail by 🔁 Round Structure Rework (RSR-001). **Shipped.**
3. **Fishing cast physics + designated fishing zones** — a new, additive slice (Fishing Zones & Cast Physics, FZP-001, not originally part of this PRD) that gives the bobber a real gravity-arced flight and gates bites to Stardew-style circular zones. Inserted here because it touches the same `FishingMechanic` cast/bite entry points as step 4 below, and landing it first avoids that step rebasing around it.
4. Carryable fish + storage deposit flow, replacing the auto-report-catch path (Decision 5) — detailed implementation lives in Carryable Fish + Storage Deposit (CFS-001).
5. Shop hut, interaction, ShopUI, CoinManager, upgrade purchase and persistence (Decisions 8-9).
6. PlayerRodTarget, fish-slap, water float — the chaos/clip layer, built once the core loop above is functional (Decisions 6-7).
7. Yell-scares-fish wiring, last since it's a small independent addition (Decision 10).

Each slice should be manually playtested with multiple local instances before moving to the next, consistent with this project's existing build-order convention.

### Naming Note

This feature sits deliberately between the shipped MVP and the eventual public Demo — it's a playtest-only slice to validate day-phase chaos and the shop loop before Night is designed and built, hence "Day → Shop Slice (Pre-Demo)" rather than either label.
