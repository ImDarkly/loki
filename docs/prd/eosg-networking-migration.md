# EOSG Networking Migration
**Version:** 1.0
**Date:** August 4, 2026
**Status:** CLOSED - implemented (PR #153-#158, #165, #166, 2026-08-18)
**Owner:** Solo Developer
**Supersedes:** "EOS Crossplay" (Notion, July 21, 2026) — confirmed dead by project owner. That doc targeted GD-EOS and full Steam+Epic crossplay; this PRD targets EOSG only and descopes Steam.
---
## Problem Statement
The game's current networking (`autoloads/network_manager.gd`) uses `ENetMultiplayerPeer` with manual IP/port entry. There is no automatic NAT traversal (no UPnP implementation despite it being planned in the original migration doc, no relay) — hosting across the internet works only if the host manually forwards their router port. This is the single biggest blocker to "it just works" online play, which is the current top priority ahead of any Steam crossplay work.

Separately, an EOSG transport spike is underway (issues #139–142) verifying that `EOSGMultiplayerPeer` (from the `3ddelano/epic-online-services-godot` plugin) is viable as a drop-in replacement transport, using EOS's own P2P relay — removing the NAT traversal problem entirely without needing to build UPnP support.
## Solution
Replace `ENetMultiplayerPeer` + manual IP entry with `EOSGMultiplayerPeer` + a short numeric room code backed by EOS Lobby search. The host logs into EOS anonymously (Device ID), creates an EOS Lobby with a random 6-digit code stored in the lobby's searchable Bucket ID field, and the multiplayer peer is created via EOSG. A joining player logs in anonymously, enters the 6-digit code, the game searches EOS Lobbies by that Bucket ID, and joins the matching lobby's peer.

Godot's high-level multiplayer API (`multiplayer.*`, `@rpc`) is peer-agnostic: every game system currently built on top of it (`game_manager.gd`, `danger_manager.gd`, `round_manager.gd`, `quota_manager.gd`, `zone_manager.gd`, `rock_manager.gd`, `coin_manager.gd`, `health_component.gd`, `player.gd`, voice chat networking) requires **no changes**. Only the transport/discovery/auth layer (`network_manager.gd` and `lobby.gd`/`.tscn`) is rewritten.
## User Stories
1. As a **host**, I want to **log into EOS anonymously with one click**, so that **I don't need an Epic account to play**
2. As a **host**, I want to **create a game and receive a 6-digit code**, so that **I can share it with friends without dealing with IP addresses or router configuration**
3. As a **joining player**, I want to **log into EOS anonymously**, so that **I can join without an Epic account**
4. As a **joining player**, I want to **enter a 6-digit code to join a game**, so that **I don't need the host's IP address or any router setup on either side**
5. As a **joining player**, I want to **get a clear "Connection failed" message if the code is invalid or the host is gone**, so that **I'm not left staring at a frozen screen**
6. As a **host**, I want to **have my lobby stop appearing in searches once I start the game**, so that **no one can join mid-match**
7. As a **host**, I want to **exit cleanly and have my lobby removed from search**, so that **no one tries to join a dead game**
8. As a **player**, I want to **see the existing player list and "Start Game" flow work exactly as before**, so that **the rest of the lobby UX is unaffected by the transport change**
9. As a **developer**, I want to **every existing game system (danger, round, quota, zones, rocks, coins, health, fishing, voice) to keep working unmodified**, so that **this migration touches only the networking layer, not gameplay code**
10. As a **developer**, I want to **the lobby member cap to match the actual number of spawn points in `player.gd`**, so that **a 5th player can't join and get silently placed on top of player 1**
## Implementation Decisions
### Decision 1: Library — EOSG, not GD-EOS
Continue the current direction (issues #139–142) rather than reverting to GD-EOS. This PRD assumes `EOSGMultiplayerPeer` is confirmed functional per the EOSG transport spike. **Note:** the previous "EOS Crossplay" doc claimed EOSG does not provide a `MultiplayerPeer` — this was verified false during this PRD's research; `EOSGMultiplayerPeer` exists in EOSG's official docs with `create_server`/`create_client`/`create_mesh`. That doc is confirmed dead by the project owner.
### Decision 2: Authentication — Device ID only
No Epic account login, no Steam external credential linking, no friends list. Purely anonymous `HAuth` Device ID login, matching the existing `eosg_spike.gd` device-id path. Epic account login is explicitly out of scope (see below).
### Decision 3: Room code — 6-digit code via Lobby Bucket ID
- On `host_game()`, generate a random 6-digit code (100000–999999) and set it as the EOS Lobby's Bucket ID at creation.
- On `join_game(code)`, search lobbies by Bucket ID.
- No uniqueness pre-check when generating a code — the search space (900,000 combinations) and short lobby lifetime make collisions rare enough that it's not worth the added complexity.
- If a search returns more than one lobby for a code (collision), surface the list to the joining player to pick from, rather than silently guessing.
- **Open verification item:** the exact EOSG method/signature for lobby search (e.g. `HLobbies.find_lobbies_async`) was not confirmed during this PRD's research — the relevant docs page was unreachable. Confirm directly via the in-editor class reference before implementation.
### Decision 4: Lobby capacity — 4 players
`autoloads/network_manager.gd` currently sets `MAX_CLIENTS := 16`, but `player.gd`'s `_setup_authority_from_name()` only has 4 hardcoded `spawn_positions`. A 5th player silently falls back to `spawn_positions[0]`, stacking on player 1. Set EOS Lobby `max_lobby_members = 4` to match reality. Expanding beyond 4 players is a separate, later task (needs more spawn points).
### Decision 5: Lobby lifecycle
- On `game_manager.start_game()`, close the lobby to further search/join (change permission level away from publicly-advertised, and/or remove it from search) as part of the same code path that triggers the scene-load RPC.
- On graceful host exit (`disconnect_from_game()`, window close), explicitly leave/delete the EOS Lobby rather than relying on EOS-side cleanup.
- On host crash (no graceful exit), rely on EOS's own lobby TTL to eventually clear the dead lobby. No custom crash-detection or host migration is built.
### Decision 6: Scope of file changes
| File | Change |
|---|---|
| `autoloads/network_manager.gd` | Full rewrite: EOS Device ID login, Lobby create/search/join, `EOSGMultiplayerPeer` creation. **Keep the existing autoload name `NetworkManager`** and its public signal/method shape as close as possible, since `lobby.gd` is the only caller — minimizes blast radius. |
| `scenes/lobby.gd` / `.tscn` | Replace IP/port input fields with a 6-digit code input (join) and code display (host), replace "Your IP" label with "Your code". |
| `game_manager.gd`, `danger_manager.gd`, `round_manager.gd`, `quota_manager.gd`, `zone_manager.gd`, `rock_manager.gd`, `coin_manager.gd`, `health_component.gd`, `player.gd`, `voice_chat_network.gd` | **No changes.** All peer-agnostic via `multiplayer.*` / `@rpc`. |
## Testing Decisions
EOS login and lobby operations require a live EOS SDK connection (network, real credentials) — the same constraint that already keeps `tests/eosg_spike/` out of the GUT suite (`.gutconfig.json` only scans `tests/unit/`, and the spike needs two processes/devices to verify).
- **Unit-testable (GUT, `tests/unit/`):** pure logic only — 6-digit code generation (format, range 100000–999999), any request/response parsing that doesn't require a live connection.
- **Not unit-testable:** `login()`, `host_game()`, `join_game()` against real EOS — verified manually via a two-device run, following the same pattern as the existing `tests/eosg_spike/` acceptance criteria.
## Out of Scope
- **Steam crossplay** — explicitly wanted for the eventual demo, but descoped from this PRD. Priority #1 right now is "online works at all" via EOS; Steam crossplay will be its own follow-up PRD.
- **Epic account login / friends list / invites** — Device ID only for now.
- **Host migration** — if the host disconnects, the session ends, matching the original `multiplayer-migration.md` decision.
- **Expanding beyond 4 players** — separate task, needs new spawn points in `player.gd`.
- **Public matchmaking / lobby browser** — join is code-only, no "random public game" list.
- **GD-EOS removal cleanup** — tracked separately in issue #142; this PRD assumes it's already done or in progress.
## Further Notes
### Unverified premise (now resolved)
This PRD was written on the project owner's statement that issues #141 (Spawner & Synchronizer Verification) and #142 (GD-EOS Removal) are closed. This could **not** be independently re-confirmed via the GitHub API during this PRD's research due to unauthenticated rate-limiting (60 req/hour exhausted). **Re-verify both issues' state before starting implementation** — if #141 is not actually closed, `EOSGMultiplayerPeer` itself is not yet confirmed stable and this PRD's foundation is premature.

**Re-verified 2026-08-19:** issue #141 (Spawner & Synchronizer Verification) and #142 (GD-EOS Removal) are both CLOSED. The migration shipped via PR #153–#158 (EOSG host/join/room code/lobby lifecycle) and #165/#166 (map config + EOS RTC voice).
### Why EOSG over GD-EOS (history)
GD-EOS's own network transport was previously confirmed working after extensive debugging (per the July 27 EOSG-transport-spike spec), but was abandoned anyway in favor of EOSG for tooling/distribution reasons (EOSG ships precompiled via the Asset Library; GD-EOS requires a local MSVC/SCons build, documented in the now-obsolete `BUILD.md`). Issues #131–133 (old GD-EOS transport/auth/full-migration work) were closed as "superseded by EOSG migration" on July 27, 2026, without ever reaching production. The EOSG path carries a real risk of repeating that outcome if #141 turns out not to fully verify — there is no fallback plan in this PRD if that happens.