**Feature ID:** SHP-001

**Status:** Ready for Development — ready-for-agent

**Owner:** Solo Developer

**Tech Stack:** Godot 4.6, GDScript, GD-Sync

---

## Problem Statement

The Day → Shop Slice (Pre-Demo) PRD's Decisions 8-9 describe a shop hut, ShopUI, CoinManager, and upgrade purchase/persistence only in prose, with several open questions left unresolved: whether the shop is gated on round phase, whether purchases are host-only or trust-the-client, whether upgrades are per-player or team-wide, what happens to an open shop panel on restart, and how races/duplicate purchases are handled. Without resolving these, the shop and upgrade system cannot be implemented consistently with the rest of the codebase's host-authority and trust-the-client patterns.

## Solution

The shop hut reuses the exact raycast+interact system already built for the storage box (Carryable Fish + Storage Deposit PRD, Decision 5): local player raycasts forward, `interact` action (right-click) triggers the action. The shop is only interactable once the round's fishing phase has ended (`fishing_active == false`); while fishing is still active, looking at the hut shows a locked-reason prompt instead of opening the panel. Once unlocked, interacting opens a local ShopUI panel — independent per player, no shared lock — showing the team's current stored fish, coins, and available upgrades. Any connected player can sell all stored fish for coins (trust-the-client, host-validated and broadcast) and can buy either of two one-time, team-wide permanent upgrades, both purchases validated host-side against funds and duplicate-ownership. Coins and upgrade-ownership flags are owned by a new host-authoritative `CoinManager` sibling node, following the exact broadcast pattern already established by `QuotaManager`, and are explicitly excluded from the existing round-restart reset path — except that any player's open ShopUI panel is auto-closed as part of that same restart, since the hut re-locks the instant `fishing_active` flips back to `true`.

## User Stories

### Approaching and Unlocking the Shop

1. As a player, I want to walk up to a physical shop hut and aim my camera at it, so that interacting with it feels consistent with how I already interact with the storage box.
2. As a player, I want to see a prompt explaining the shop isn't available yet if I look at it while fishing is still active, so that I understand why nothing happens when I try to interact.
3. As a player, I want the shop to become interactable the instant the fishing phase ends, so that visiting it is my first available action once I'm done fishing for the round.
4. As a player, I want the shop to lock again once the host starts the next round, so that I understand the shop window has closed.

### Opening and Viewing the Shop

1. As a player, I want to right-click while looking at the shop hut once it's unlocked, so that the shop panel opens immediately.
2. As a player, I want to open the shop panel independently of my teammates, so that one person browsing the shop doesn't lock everyone else out.
3. As a player, I want to see our team's current stored fish count, our current coin total, and the available upgrades (owned or not) in the panel, so that I know what we have and what I can still buy.

### Selling Fish

1. As a player, I want to press a "Sell All" button to convert all our stored fish into coins at a fixed rate, so that I have currency to spend on upgrades.
2. As a player, I want any teammate to be able to sell, not just the host, so that whoever is at the shop can act on the team's behalf.
3. As a player, I want the coin total to update immediately for everyone after a sale, so that the whole team sees our new balance right away.
4. As a player, I want our stored fish count to drop to zero after selling, so that I understand the fish were consumed by the sale.

### Buying Upgrades

1. As a player, I want to spend coins on a permanent +max_health upgrade, so that the team is tougher against the shark going forward.
2. As a player, I want to spend coins on a permanent +rod-pull speed upgrade, so that teammate rescues are faster going forward.
3. As a player, I want a purchased upgrade to apply to every player on the team, not just whoever bought it, so that spending our shared coins benefits everyone.
4. As a player, I want each upgrade to be a one-time purchase, so that I understand there's no additional benefit to buying it again.
5. As a player, I want the buy button for an already-owned upgrade to be disabled, so that I'm not tempted to waste coins on something we already have.
6. As a player, I want to be prevented from buying an upgrade if we don't have enough coins, so that the purchase fails cleanly instead of putting us in an invalid state.

### Persistence Across Restarts

1. As a player, I want our coins to carry over when the host restarts the round, so that our shop progress isn't wiped out each round.
2. As a player, I want our purchased upgrades to stay active in the next round, so that spending coins has a lasting payoff.
3. As a player, I want my open shop panel to close automatically if the host restarts while I'm browsing it, so that I'm not left looking at a stale panel after the hut re-locks.

### Death and Interaction

1. As a player, I want to be unable to interact with the shop while I'm dead/spectating, so that shop access is consistent with every other interactive input being disabled in that state.

### Solo/Small-Group Testing

1. As a developer, I want to trigger sell and buy actions directly by calling internal methods, so that I can verify coin and ownership state without a live camera raycast.
2. As a developer, I want to verify that two simultaneous buy requests for the same upgrade resolve correctly (one succeeds, one is rejected), so that I can confirm the host-side validation prevents a double-charge without needing a live network race.
3. As a developer, I want to verify that a restart does not reset coins or upgrade ownership but does close any open ShopUI state, so that I can confirm the persistence/reset split is correct.

## Implementation Decisions

### Decision 1: Reuse the Existing Raycast+Interact System

The shop hut uses the same `interactable` physics layer, `interact` input action (right-click), and local-player-only forward raycast already built for the storage box (Carryable Fish + Storage Deposit PRD, Decision 5). No new input action or physics layer is introduced.

### Decision 2: Shop Interactability Gated on `fishing_active`

Unlike the storage box (which is interactable at any time), the shop hut is only interactable once `RoundManager.fishing_active` is `false`. While `fishing_active` is `true`, raycasting the hut shows a locked-reason prompt (e.g. "Shop opens after fishing ends") rather than no prompt at all — this is a new prompt state distinct from the storage box's "no prompt when not actionable" rule, specifically because there's a meaningful reason to communicate here.

### Decision 3: ShopUI Is Local, Independent, Unlocked

The shop panel is local UI state on each client, exactly like the storage box's interact prompt. Any number of players can have it open simultaneously; opening it does not lock or restrict any other player's access. It reads its data from `CoinManager`'s and `QuotaManager`'s synced values.

### Decision 4: `CoinManager` as a New Host-Authoritative Sibling Node

`CoinManager` is added to `scenes/main.tscn` as a new node, sibling to `QuotaManager`, `DangerManager`, and `RoundManager`, following the exact same host-authoritative broadcast-on-change pattern already used by `QuotaManager._sync_quota`. It owns the team's coin total and the ownership flags for each of the two upgrades.

### Decision 5: Selling Reuses `QuotaManager.apply_penalty`, No New QuotaManager Method

`CoinManager.sell_all()` is a trust-the-client RPC (`@rpc("any_peer", "call_remote", "reliable")`, same shape as `QuotaManager.report_catch`), callable by any connected peer. On the host, it reads `QuotaManager.shared_quota`, converts it to coins at a fixed, tunable rate (`@export var coins_per_fish: int = 1`), adds the result to the coin total, and consumes the stored fish by calling the existing `QuotaManager.apply_penalty(shared_quota)` — which already does exactly "subtract N, clamp at 0." No new method is added to `QuotaManager`, keeping it unaware of coins or shops (mirroring the existing precedent that `QuotaManager` stays a dumb counter, per the Round Lifecycle PRD's Decision 1).

### Decision 6: Exactly Two One-Time, Team-Wide Upgrades

Two upgrades exist for this slice: `+max_health` and `+rod-pull speed`. Each is a one-time toggle (not stackable/leveled), with a tunable cost and magnitude (`@export` values on `CoinManager`, placeholder defaults e.g. 10 coins each). A purchased upgrade applies to every player on the team, not just the buyer — `CoinManager` broadcasts the ownership flags, and every player reads them (for `+max_health`, applied wherever `PlayerHealth.max_health` is set/reset; for `+rod-pull speed`, applied wherever `PlayerRodTarget`'s pull rate is read).

### Decision 7: Purchase Is Trust-the-Client, Host Double-Validates

Buying an upgrade is a trust-the-client RPC, any peer, same shape as selling. The host validates two conditions before applying: sufficient coins, and the upgrade not already owned. Both checks exist specifically to guard against a race (two simultaneous buy requests) or a stale/desynced client — the second request in a race is a clean no-op rather than a double-charge or duplicate-ownership state. Client-side, the buy button is also disabled once the client observes the synced "owned" flag, as a UX nicety on top of the host-side guarantee (not a substitute for it).

### Decision 8: Coins and Upgrade Ownership Excluded From Restart Reset

`CoinManager`'s coin total and upgrade-ownership flags are not touched by `RoundManager.restart_round()` / `_apply_restart()` — they persist for the lifetime of the session, consistent with the parent Day → Shop Slice PRD's Decision 9.

### Decision 9: Open ShopUI Auto-Closes on Restart

Despite coins/upgrades persisting, any player's currently-open ShopUI panel is explicitly closed as part of `RoundManager._apply_restart()`'s existing per-player reset loop (the same loop that already calls `FishingMechanic.reset_for_restart()` and `Player.drop_carried_fish()` per the Carryable Fish + Storage Deposit PRD's Decision 10). This avoids a player being left looking at a stale panel after the hut re-locks per Decision 2.

### Decision 10: Shop Interaction Disabled While Spectating

The local-only raycast+interact logic that powers shop interaction only runs for the currently-enabled player instance, mirroring the existing `_enable_player()` / `_disable_player()` gating already used for movement, casting, and voice input. A dead/spectating player (per `PlayerHealth`'s spectate state) has no shop interaction available, consistent with every other interactive input already being disabled in that state.

## Testing Decisions

Good tests here validate observable state and RPC/signal outcomes from direct method calls, bypassing the camera raycast, prompt rendering, and live network connections — consistent with the existing pattern in `test_player.gd`, `test_danger_manager.gd`, and `test_round_manager.gd`.

Modules to test (deep, no live network required):

- **`CoinManager.sell_all()`** — converts the current `QuotaManager.shared_quota` to coins at `coins_per_fish`; calls `QuotaManager.apply_penalty` with the pre-sale stored-fish count; stored fish is zero after the call.
- **`CoinManager` upgrade purchase** — succeeds and deducts coins when funds are sufficient and the upgrade isn't already owned; rejects (no-op) when funds are insufficient; rejects (no-op) when already owned, even if funds are sufficient (covers the race/stale-client case from Decision 7).
- **Restart exclusion** — a simulated restart leaves `CoinManager`'s coin total and upgrade-ownership flags unchanged.
- **Shop lock state** — a direct check of shop-interactable state returns `false` when `fishing_active` is `true` and `true` when it's `false`.

Explicitly not covered by automated tests, per existing project precedent (see Pre-Demo PRD's exclusion of the shop hut's 3D interaction prompt, and Carryable Fish + Storage Deposit PRD's exclusion of the raycast/hover detection): the camera raycast/hover detection itself, the locked-reason vs. actionable prompt rendering, and the ShopUI panel's visual layout. These are validated through manual playtesting.

Prior art: follow `test_round_manager.gd` and `test_danger_manager.gd` exactly — instantiate the relevant node directly, drive state via internal methods (bypassing timers), and assert on resulting state. No mocking framework, consistent with the rest of the project.

## Out of Scope

- **Additional upgrades beyond the two named here** — deferred; this slice ships exactly `+max_health` and `+rod-pull speed`.
- **Stackable/leveled upgrades** — each upgrade is a single one-time toggle for this slice.
- **Per-player (rather than team-wide) upgrade effects** — explicitly team-wide per Decision 6.
- **Partial selling** — only "Sell All" exists; no selling a subset of stored fish.
- **A shop-wide lock or single shared panel state** — the panel is local and independent per Decision 3.
- **Any save-file or cross-session persistence beyond the current play session** — coins/upgrades persist only for the lifetime of the running session, not across game restarts/relaunches.
- **Any change to the storage box, carryable-fish flow, or `QuotaManager`'s existing interface** — this feature only adds a new sibling `CoinManager` and reuses `QuotaManager.apply_penalty` as-is.

## Further Notes

### Origin

This PRD resolves the open implementation questions in Decisions 8-9 of the Day → Shop Slice (Pre-Demo) PRD through direct discussion (grill-me style interview), the same process already used for the 4-Player Multiplayer and Round Structure Rework specs. It supersedes those two decisions' prose with the detailed decisions above; everything else in the parent PRD (carryable fish, player health, fish-slap, rod-pull, water float, yell-wiring) is unaffected and remains scoped to that document.

### Publishing Note

Published to Notion under Project Loki's Specification section, alongside the parent Day → Shop Slice (Pre-Demo) PRD and other existing specs, per this project's established Notion + `docs/prd/*.md` publishing convention (no connected issue tracker with a `ready-for-agent` label workflow).

### Dependency Note

Assumes `PlayerHealth`, the `fishing_active`/`round_active` split (Round Structure Rework), and Carryable Fish + Storage Deposit's raycast+interact system and `interactable` layer are already built, per the parent PRD's suggested build order (this feature is Decisions 8-9, landing after Decisions 1-7).

### Suggested Build Order

1. `CoinManager` node + sell/buy RPCs + host validation, tested in isolation.
2. Shop hut placeholder mesh + `fishing_active` lock state, reusing the existing `interactable` layer/raycast.
3. ShopUI panel (local, independent per player) reading `CoinManager`/`QuotaManager`.
4. Restart-exclusion wiring (skip `CoinManager` in reset) + ShopUI auto-close wiring (add to existing per-player restart loop).
5. Team-wide upgrade effect application (`PlayerHealth.max_health`, rod-pull speed read sites).

Each slice should be manually playtested with multiple local instances before moving to the next, consistent with this project's existing build-order convention.
