**Feature ID:** CFS-001

**Status:** Ready for Development

**Owner:** Solo Developer

**Tech Stack:** Godot 4.6, GDScript

---

## Problem Statement

Right now a caught fish is auto-reported to the shared quota the instant a reel succeeds (`FishingMechanic._on_reel_timer_timeout()` calls `_report_catch_to_host(1)` directly). There is no physical object the player is holding, no trip to make, and nothing at stake between landing a fish and it counting toward the team. This makes catching feel instant and abstract, and it removes the vulnerability window the rest of the Pre-Demo slice depends on — the shark, teammates, and future chaos mechanics (fish-slap, water float) have nothing to threaten between catch and credit.

This PRD carves out just Decision 5 of the Day → Shop Slice (Pre-Demo) PRD — the carryable-fish and storage-deposit flow — as its own focused, buildable unit, ahead of the shop and chaos-mechanic slices that depend on it.

## Solution

On a successful reel, the fish is no longer auto-reported. Instead the player enters a carrying state, holding the fish in both hands, and must physically walk to a storage box and interact with it (Minecraft-style: aim the camera at the box, right-click) to deposit it — which is the point the catch actually credits the team's shared quota. Carrying is exclusive: no other item (starting with the fishing rod itself) can be held at the same time, and only one fish can be carried at once. If the carrying player takes any damage (via `PlayerHealth`, assumed already built), the held fish is destroyed with no credit — mirroring a failed catch. The carried state is visible to teammates.

## User Stories

### Carrying a Fish

1. As a player, I want a fish I just caught to appear held in both my hands, so that catching feels physical rather than instant and abstract.
2. As a player, I want to see my fishing rod disappear while I'm carrying a fish, so that it's clear my hands are full and I can't fish again until I deposit.
3. As a player, I want to be prevented from casting a new line while carrying a fish, so that I can't stack catches or lose track of what I'm holding.
4. As a player, I want to only be able to carry one fish at a time, so that the carry step stays a deliberate, repeated action rather than a one-time stockpiling trip.
5. As a player, I want to see my teammates holding their fish too, so that I know who's mid-delivery and who's vulnerable.

### Finding and Using the Storage Box

1. As a player, I want a single physical storage box in the world, so that there's one clear, discoverable destination to deliver fish to.
2. As a player, I want to see a prompt appear when I aim my camera at the storage box while carrying a fish, so that I know I can interact with it right now.
3. As a player, I want the prompt to disappear if I look away or I'm not carrying anything, so that I'm not shown an action I can't currently take.
4. As a player, I want to right-click while looking at the box to deposit my fish, so that the interaction feels immediate and readable, like placing/breaking blocks in Minecraft.
5. As a player, I want my fish to be gone from my hands and the rod to reappear immediately after depositing, so that I get clear confirmation the deposit worked.
6. As a player, I want the team's shared quota to update the moment I deposit, so that my contribution is immediately visible to the team.

### Losing a Carried Fish

1. As a player, I want my held fish to be at risk while I'm carrying it, so that the shark and future chaos mechanics have something real to threaten.
2. As a player, I want to lose my currently-held fish if I take damage while carrying it, so that getting bitten mid-carry has a real cost.
3. As a player, I want a fish lost to damage to just vanish (no credit, no way to pick it back up), so that the loss is unambiguous, like a failed reel.
4. As a player, I want my carried fish (if any) to be cleared out when a round restarts, so that I never start a new round holding a stale fish from the last one.

### Solo/Small-Group Testing

1. As a developer, I want to trigger the carry, deposit, and drop transitions directly by calling internal methods, so that I can verify state without needing a live camera raycast or a real shark encounter.
2. As a developer, I want to verify that a deposit reports exactly one catch to the quota manager and that a damage-drop never does, so that I can be confident credit is only ever awarded on an actual delivery.

## Implementation Decisions

### Decision 1: `is_carrying` Lives on `Player`, Not `FishingMechanic`

Carrying is a general "what is the player holding" concern, not a fishing-specific one — it's meant to gate all item use (starting with the rod, extensible to other future held items). It is a plain boolean property (plus a reference to the held-fish visual node) on `Player`, sitting alongside `FishingMechanic` as a sibling concern, not folded into `FishingMechanic.State`. This keeps `FishingMechanic`'s existing state machine (already synced over the network and read by remote-render logic and the danger system's `fish_fled` check) unchanged in meaning.

### Decision 2: Catch → Carry Handoff via Signal

`FishingMechanic` keeps its existing `reel_success(quota: int)` signal, but on reel success it no longer calls `_report_catch_to_host()` itself — that call is removed from `_on_reel_timer_timeout()`. `Player` connects to its own child `FishingMechanic`'s `reel_success` signal and, on receiving it, starts carrying. This matches the existing pattern in the codebase of child systems emitting signals (`reel_success`, `reel_failure`, `bite_occurred`, `fish_fled`, `quota_penalty`) rather than reaching into their parent/consumer directly.

`personal_catch_count` / `personal_catch_changed` and the existing catch-feedback ding/flash (`catch_feedback_manager.play_catch_success()`) still fire at this same moment — the catch feedback text should be updated from "+1 Fish" to something like "Fish Caught!" since the quota itself hasn't moved yet. Team quota only moves at deposit.

### Decision 3: Rod Hidden, Not Reparented, While Carrying

While `is_carrying` is true, the existing rod mesh (currently a permanent child of the right hand) is simply hidden (`visible = false`), and shown again on deposit, drop, or round restart. No reparenting or detaching. This is scoped intentionally minimal — a full equip/unequip system is out of scope for this slice.

### Decision 4: Cast Gating Lives at the `Player` Input Call Site

`FishingMechanic.can_cast()` is unchanged and still only checks its own internal state (`current_state == IDLE and _is_fishing_active()`). The `is_carrying` check is added where casting is actually triggered, in `Player`'s input handling: casting requires both `not is_carrying` and `fishing_mechanic.can_cast()`. This keeps `FishingMechanic` decoupled from any concept of what the player is holding — consistent with how it already knows nothing about `PlayerHealth` or other player-level systems.

### Decision 5: Minecraft-Style Raycast Interaction, Not a Proximity Area

Interaction is camera-forward raycast based, not an `Area3D` proximity trigger. A new physics layer (`interactable`) is added; the storage box's collider sits on that layer only, so the ray isn't blocked by teammates or the shark. The local player raycasts every frame (mirroring how casting already reads `-global_transform.basis.z` for direction) out to a tunable `interact_range` (default `3.0`), and only against the `interactable` layer. This logic runs only for the locally-controlled player instance — mirroring the existing `_enable_player()` / `_disable_player()` gating already used for input and voice chat.

A new input action, `interact`, bound to right-click (no conflict — `cast_line` and `reel` both use left-click).

### Decision 6: Interact Prompt — Shown Only When Actionable

The on-screen interact prompt shows only when both conditions are true: the local player's raycast is currently hitting the storage box, AND `is_carrying` is true. If the player is carrying nothing, or looking away, no prompt is shown — there's exactly one action this box supports right now (deposit), so there's no value in showing a prompt for a no-op.

### Decision 7: Deposit and Drop Are Distinct Player Methods

Three methods live on `Player`:

- **`start_carrying()`** — called on `FishingMechanic.reel_success`. Sets `is_carrying = true`, spawns/attaches the held-fish visual, hides the rod. Syncs `is_carrying` to other clients.
- **`deposit_carried_fish()`** — called when `interact` is pressed while the raycast is hitting the storage box and `is_carrying` is true. Calls the existing `QuotaManager.report_catch(1)` RPC (unchanged — already host-authoritative), clears `is_carrying`, destroys the held-fish visual, shows the rod. No-op (does not call `report_catch`) if not currently carrying.
- **`drop_carried_fish()`** — called from two triggers: (a) `PlayerHealth.health_changed` firing with a lower value than previously tracked (any damage, treated as PlayerHealth already being a built, available module per this feature's scope), and (b) round restart. Clears `is_carrying`, destroys the held-fish visual with **no** call to `report_catch`, shows the rod. Functionally identical outcome for both triggers — the fish is simply gone, same as a failed reel.

### Decision 8: `is_carrying` Is Synced, Held Fish Is Visible to Teammates

Unlike the personal reel-meter UI (deliberately private, local-only), a held fish is a visible object on the player's body with team stakes (it can be lost to damage, and is a target for future chaos mechanics like fish-slap). `is_carrying` is synced via a lightweight on-change RPC, following the same pattern as the existing `sync_yelling` RPC (`@rpc("any_peer", "unreliable", "call_remote")`) — not a per-frame `MultiplayerSynchronizer` property, since it only changes on discrete catch/deposit/drop events.

### Decision 9: Single Hardcoded Storage Box, Placeholder Mesh

One storage box exists for this slice, matching the project's existing single-location scope discipline. It's a plain gray/brown `BoxMesh` `StaticBody3D` with a collider on the new `interactable` layer, placed at a hardcoded position near the water's edge in `main.tscn` — no spawn-point search, no multiple containers. The held fish reuses `FishManager`'s existing orange `BoxMesh`/ORM-material primitive, reparented to the player instead of floating in water. Both are placeholders consistent with the project's no-art-assets-yet convention (see Danger System PRD Decision on shark mesh, MVP PRD Decision 7).

### Decision 10: Restart Reset

A new `Player.reset_for_restart()` is added, called from `RoundManager._apply_restart()`'s existing per-player loop (which already calls `FishingMechanic.reset_for_restart()` on each player). It calls `drop_carried_fish()` if currently carrying — same "destroy, no credit" behavior as a damage-drop.

## Testing Decisions

Good tests here validate observable state and signal/RPC outcomes from direct method calls, bypassing the camera raycast, prompt rendering, and live network connections — consistent with the existing pattern in `test_player.gd`, `test_fishing_mechanic.gd`, and `test_danger_manager.gd`.

Modules/behaviors to test (added to the existing `test_player.gd`):

- **`start_carrying()`** — sets `is_carrying` to true; held-fish node exists after the call.
- **`deposit_carried_fish()`** — calls `report_catch(1)` exactly once when carrying; clears `is_carrying`; destroys the held-fish node. Calling it while not carrying is a no-op and does not call `report_catch`.
- **`drop_carried_fish()`** — clears `is_carrying`; destroys the held-fish node; never calls `report_catch`, regardless of trigger (damage or restart).
- **Cast gating** — casting is blocked when `is_carrying` is true, verified by calling the same input-handling path already exercised by existing `test_player.gd` tests.

Explicitly not covered by automated tests, per existing project precedent (see Pre-Demo PRD's exclusion of the shop hut's 3D interaction prompt): the camera raycast/hover detection itself, the interact prompt's visibility toggling, and the held-fish mesh's visual attachment/animation. These are validated through manual playtesting.

## Out of Scope

- **Recoverable dropped fish** — a fish lost to damage is destroyed outright, not a pickup object other players can retrieve.
- **Multiple storage boxes** — one hardcoded box for this slice.
- **Shop UI, selling, coins, upgrades** — covered separately by Decisions 8-9 of the parent Day → Shop Slice PRD; this PRD only covers catch → carry → deposit.
- **`PlayerHealth` module itself** — treated as an existing prerequisite (Decision 1 of the parent PRD); this feature only consumes its `health_changed` signal.
- **Fish-slap, rod-pull, water float** — separate chaos mechanics from the parent PRD (Decisions 6-7), unaffected by and independent of this slice beyond both eventually threatening a carried fish.
- **Rod re-equip animation, two-handed IK, or any pose/animation work** — the rod is simply shown/hidden; no animation system is introduced.
- **Deposit-specific feedback (sound/flash/text)** — only the existing quota label update; no new feedback moment beyond what already fires at catch time.

## Further Notes

### Publishing Note

Published to Notion under Project Loki's Specification section, alongside the parent Day → Shop Slice (Pre-Demo) PRD and other existing specs, per this project's established Notion + `docs/prd/*.md` publishing convention (no connected issue tracker).

### Dependency Note

This slice assumes `PlayerHealth` (Decision 1 of the Day → Shop Slice PRD) is already built and exposes `health_changed(value)`. Per the parent PRD's suggested build order, this is step 3, landing after PlayerHealth (step 1) and the `fishing_active`/`round_active` split (step 2).

### Relationship to Parent PRD

This document narrows Decision 5 of the Day → Shop Slice (Pre-Demo) PRD into its own standalone, buildable unit. It supersedes that decision's original prose with the more detailed interaction model above (raycast-based interact, not a proximity `Area3D`) — everything else in the parent PRD (shop, coins, fish-slap, rod-pull, water float, yell-wiring) is unaffected and remains scoped to the parent document.
