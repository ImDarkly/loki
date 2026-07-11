**Feature ID:** MP-001
**Status:** Ready for Development
**Owner:** Solo Developer
**Tech Stack:** Godot 4.6, GDScript, GD-Sync

---

## Problem Statement

The game currently only supports one player. The entire premise of Project Loki — yelling to warn teammates at a real cost, sharing a quota, coordinating under pressure — requires more than one person in the world at the same time. Right now there is no lobby, no way for a second player to connect, no shared state of any kind, and no notion of \"my player\" vs \"someone else's player.\" `DangerManager` and `FishingMechanic` were both built assuming exactly one `Player` node exists in the scene.

GD-Sync is installed and configured (API keys in place), but nothing in the project uses it yet.

## Solution

Add a manual-join-code lobby flow (host creates, up to 3 friends join with a code) that transitions into the existing fishing world once the host starts the round. One connected client is elected host by GD-Sync and is authoritative for spawning, the danger system, and the shared team quota — everyone else runs the same game code but skips the host-only logic and simply reflects what's broadcast to them. Player movement, fishing state, danger events, and quota are synchronized over GD-Sync's relay network; each client still renders everything locally from synced state rather than replicating raw visuals, keeping the rendering layer swappable when real art assets replace today's placeholder geometry.

## User Stories

### Hosting & Joining

1. As a player, I want to create a lobby and receive a short join code, so that I can share it with my friends over voice chat.
2. As a player, I want to type in a join code to connect to a friend's lobby, so that I can play with them without needing their IP address or any port forwarding.
3. As a player, I want to see who else has joined the lobby before the round starts, so that I know we're ready to begin.
4. As the host, I want a \"Start Game\" control that only I can see and use, so that the round begins when our group is ready, not automatically.
5. As a player, I want the lobby to stop accepting new joins once the host starts the round, so that a friend can't accidentally wander into a round that's already in progress.
6. As a player, I want a clear error if my join code is wrong or the lobby is full, so that I'm not left wondering why nothing happened.

### Entering the World

1. As a player, I want to be placed at a distinct starting position from my teammates when the round begins, so that we don't spawn stacked on top of each other.
2. As a player, I want my own camera and controls to work exactly as they do today, so that multiplayer doesn't change how solo movement/casting/reeling feels.
3. As a player, I want to see my teammates' characters moving and turning smoothly, so that the world feels alive and populated.
4. As a player, I want teammates who are far away or looking elsewhere to visibly be doing so (position + facing synced), so that I can find them by sight.

### Seeing Teammates Fish

1. As a player, I want to see a teammate's line and bobber appear in the water when they cast, so that I know they're actively fishing.
2. As a player, I want a teammate's bobber to visibly twitch when their fish bites, so that I understand what's happening to them without asking.
3. As a player, I want a teammate's line to return to their rod tip when they succeed or fail, so that their fishing state is always legible from the outside.
4. As a player, I want teammates' individual reel-meter UI to stay private to them, so that my screen isn't cluttered with four meters at once.

### Shared Quota

1. As a player, I want to see one shared quota number that updates when *any* teammate catches a fish, so that I understand our progress is a team effort.
2. As a player, I want my own catch to count toward the team total immediately upon success, so that the reward feels instant and connected to my action.
3. As a player, I want to still see my own individual catch count separately from the team total, so that I know my personal contribution.
4. As a player, I want the shared quota to never go negative, so that a bad round doesn't produce a confusing or absurd number.

### Shared Danger

1. As a player, I want the shark to target whichever player is currently closest to it, so that the threat feels responsive to everyone's positioning, not just one designated \"tank.\"
2. As a player, I want any teammate's yell to repel the shark, regardless of who it's chasing, so that the team can protect each other, not just themselves.
3. As a player, I want to see the same shark, in the same position, at the same time as my teammates, so that we're all reacting to one shared threat rather than four separate simulations.
4. As a player, I want only my own fish to escape if the shark attacks me specifically while I'm reeling, so that a teammate's bad luck doesn't cost me my catch.
5. As a player, I want the shared quota to drop by 3 whenever the shark successfully attacks anyone, regardless of who it targeted, so that an unrepelled shark is always a team cost.

### Solo/Small-Group Testing

1. As a developer, I want to run 2-4 instances of the game on one machine and have them connect to each other, so that I can test multiplayer without needing separate hardware.
2. As a developer, I want the quota, targeting, and spawn-slot logic to be testable without a live network connection, so that I can verify correctness quickly and repeatedly.
3. As a developer, I want to be able to identify, from logs or debug output, which connected client is currently the host, so that I can confirm host-only logic is running in the right place.

### Resilience (Baseline Only)

1. As a player, I want the game to not crash if a teammate's connection drops mid-round, so that one person's bad wifi doesn't end the session for everyone.
2. As a player, I want to understand that if the host disconnects, the round ends for MVP, so that I'm not confused when this isn't seamlessly handled (host migration is out of scope for this pass).

## Implementation Decisions

### Decision 1: Join Flow — Manual Code, Friends List Deferred

Players join via a manual join code entered on a lobby screen (`GDSync.lobby_create` / `GDSync.lobby_join`). Steam-friends-list/invite joining is a documented post-MVP upgrade and requires no architectural changes now — it's an additional entry point into the same `lobby_join` call, not a redesign.

### Decision 2: Separate Lobby Scene

The lobby is its own scene and becomes the project's boot scene (`run/main_scene`). It shows connect/create UI and a live list of joined players. When the host starts the round, `GDSync.call_func_all()` triggers every connected client to `change_scene_to_file` into the game scene at the same moment. The fishing world scene is never loaded, and none of its `_ready()` logic (danger spawn timers, etc.) runs, until the round has actually started. The lobby closes to new joins at that point (using GD-Sync's native lobby open/close support) — no mid-round joining for this pass.

### Decision 3: Player Becomes a Spawnable Scene

The player character is extracted from the game's boot scene into its own reusable scene so it can be instantiated once per connected client at runtime. A `Players` container node holds all spawned instances. Existing exported tuning values and node structure (head, camera, hands, fishing rod, fishing mechanic child, voice chat manager child) are unchanged — this is a packaging change, not a redesign of the player itself.

### Decision 4: Host-Only Spawn Loop, Fixed Spawn Slots

Only the host (`GDSync.is_host()`) runs the spawn loop, once, after the scene change. It iterates connected clients in join order and instantiates a player for each via GD-Sync's `NodeInstantiator` (which handles replicating the spawn to all other clients, including replication logic for anyone who reconnects). Each spawned player is assigned one of 4 fixed, hardcoded world positions in a small arc facing the water, assigned strictly by join order — no dynamic spawn-point search. This avoids two clients racing to spawn the same player and avoids players overlapping at spawn.

### Decision 5: Ownership & Local-Player Gating

Each spawned player is assigned to its owning client via GD-Sync's node ownership system (`set_gdsync_owner`). The player script determines whether it's the locally-controlled instance by comparing its assigned owner to the local client's own ID. All input-reading code (movement, jump, mouse-look, cast/reel input), and the active-camera flag, are gated on this local check — ungated for the owning client, skipped entirely for every other client's copy of that same player. Non-local player instances do not run physics-driven movement at all; they are purely puppeted by synchronized position/rotation values (Decision 6). Cosmetic idle animation (hand bounce, walk squish, camera shake) is not gated — it runs for every player instance based on that instance's own synced velocity, so remote players still look alive rather than robotic.

### Decision 6: Movement Sync Scope

Only three values are synchronized per player: world position, body yaw (left/right facing), and head pitch (up/down look). No other per-frame cosmetic state (bounce, squish, shake offsets) is synchronized — those are cheap to recompute locally from synced position deltas and would otherwise be pure bandwidth waste for an invisible-if-slightly-off value.

### Decision 7: Fishing Visibility — Sync State, Not Geometry

A fishing state enum and the single cast-target position are synchronized per player, not the line/bobber geometry itself. Every client's own copy of the fishing rendering logic already knows how to draw a line and bobber from those two values locally — this is reused as-is for remote players, just invoked in a render-only mode that skips the input-driven parts (bite timer, reel-meter math, cast/reel input reading). This keeps the network layer decoupled from *how* fishing looks, which matters because the line/bobber/rod visuals are expected to be replaced with real asset-pack models later — that swap only touches the local rendering function, never the networking code. The personal reel-meter UI (green zone, player bar) is never synchronized; it was already private to each client via a local `CanvasLayer` and stays that way.

### Decision 8: Shared Quota Ownership

A new manager, sibling to the danger system rather than per-player, owns a single team-wide quota value for the whole session. It exposes two operations: report a successful catch (adds 1) and apply a penalty (subtracts a given amount, clamped at a floor of 0). Both operations are host-only — any client can attempt a catch or trigger a penalty condition locally, but only the host's copy of the manager is allowed to actually change the shared value, which it then broadcasts to everyone. Every client's quota display reads from this shared value instead of a local counter. Individual per-player catch counts (for personal bragging-rights display, not for the win condition) are tracked separately as lightweight per-client data, not inside this manager.

### Decision 9: Trust-the-Client Catch Reporting

When a client's own reel-meter check succeeds, that client reports the catch to the host-owned quota manager and trusts that report — the host does not independently re-verify the reel-bar position server-side. This prevents quota desync (everyone agreeing on one number) without the added complexity of streaming live reel-bar state to the host every frame of every reel. This is considered acceptable for a cooperative game among friends; true anti-cheat validation is out of scope and can be added later if it's ever actually a problem.

### Decision 10: Danger System Becomes Multi-Player Aware, Host-Only

The danger system's logic continues to run only on the host (as it already conceptually was a single sibling-of-Player system, now explicitly gated on host status). Instead of tracking one fixed player reference, it recalculates the nearest connected player every frame during its approach state and targets that one — this can change mid-approach if a closer player becomes available. Any connected player's yell state (not just the target's) causes it to retreat, reflecting that yelling is a team-protective action, not a self-defense one. Its shark position and state are broadcast so every client renders the same shark in the same place, rather than each client simulating its own.

### Decision 11: Attack Consequences Split Between Personal and Shared

When the shark successfully attacks, two independent effects occur: (1) if the specific player it targeted has an active reel, that player's fish escapes — teammates who are also reeling elsewhere are unaffected; (2) the shared team quota always drops by a fixed penalty amount regardless of who was targeted or whether anyone was reeling at all. These are two separate, independently-triggered consequences, not one combined effect.

### Decision 12: Host Authority Pattern

A recurring pattern is used across the spawn loop, the danger system, and the quota manager: state-changing logic runs exclusively behind a host check, and the resulting state is broadcast for every other client to passively reflect. No client other than the host ever mutates the shared quota value, decides shark targeting, or runs the spawn loop — this keeps \"who's allowed to change what\" consistent and predictable across every networked system in this feature, rather than inventing a different authority rule per module.

## Testing Decisions

Good tests here validate external behavior (given this input, is the resulting state/signal correct), not networking plumbing — consistent with the project's existing testing philosophy (see `test_danger_manager.gd`, `test_fishing_mechanic.gd`) and the MVP spec's explicit guidance to rely on manual playtesting rather than automated integration tests for real multiplayer networking.

**Modules to test (deep, no live network required):**

- **Quota manager** — report-catch increments by 1; apply-penalty decrements by the given amount; penalty never drops the value below 0; multiple catches and penalties compose correctly in sequence.
- **Danger system nearest-player targeting** — given a set of player positions, the correct nearest one is selected; the selection updates correctly when a closer player is introduced; \"any player yelling\" correctly triggers retreat when at least one of several players has yelling state true, and does not trigger when none do.
- **Spawn slot assignment** — given a join order, each client is assigned a distinct one of the 4 fixed positions, with no duplicates and no client left unassigned.

**Explicitly not covered by automated tests:** lobby creation/joining, `NodeInstantiator` spawn replication, node ownership assignment, `PropertySynchronizer` wiring, and any other GD-Sync plumbing. These require a live relay connection and are validated through manual multi-instance playtesting (per the project's own testing strategy for networked systems), not GUT tests.

**Prior art:** Follow the existing `test_danger_manager.gd` pattern — instantiate the relevant node directly, drive it by calling internal methods (bypassing timers), and assert on resulting state/signals. No mocking framework, consistent with the rest of the project.

## Out of Scope

- **Host migration** — if the host disconnects, the round ends for this pass; reassigning host mid-round is deferred.
- **Server-side catch validation / anti-cheat** — trust-the-client reporting is accepted for MVP (Decision 9).
- **Mid-round joining** — the lobby locks once the host starts; late joiners are not supported yet.
- **Proximity voice transmission (GD-Sync `VoiceChat` node)** — this is Phase 2 of the separate Voice Chat Manager feature and is not part of this feature, though it will ride on the same networking foundation once built.
- **Yelling causing nearby fish to flee (30m radius)** — this is part of the separate, still-unplanned Yelling Mechanic feature and is independent of shark-repelling yell behavior covered here.
- **Cosmetic remote-player juice sync** (hand bounce, camera shake) — deliberately left client-local per Decision 6.
- **Friends-list/invite joining** — deferred per Decision 1.
- **Public matchmaking / lobby browsing** — not needed for the manual-code flow chosen here.

## Further Notes

### Publishing Note

This PRD was authored by synthesizing a live design discussion (grill-me style interview) rather than a fresh interview. It is being published to Notion under Project Loki's Specification section, mirroring the existing Core Fishing Mechanic, Danger System, and Voice Chat Manager spec pages, since this repository does not have a connected issue tracker with a `ready-for-agent` label workflow — Notion + `docs/prd/*.md` is this project's equivalent publishing target.

### Suggested Build Order

The implementation decisions above are written as one coherent design, but should be built and playtested as sequential slices rather than one large change: (1) lobby + host spawn + movement sync only, with no fishing/quota/danger networked yet — validates the core plumbing; (2) fishing state sync; (3) shared quota; (4) networked danger system. Each slice should be manually playtested with multiple local instances before moving to the next.

### Dependency Note

This feature assumes the currently-unmerged Voice Chat Manager threshold fix lands first, since `is_yelling` correctness matters directly to Decision 10's \"any player yelling\" check.
