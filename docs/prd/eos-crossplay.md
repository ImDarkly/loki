## EOS + Steam True Crossplay Migration

**Version:** 1.0
**Date:** July 21, 2026
**Status:** DRAFT — pending EOS product registration and spike verification
**Owner:** Solo Developer
**Supersedes/Amends:** `.opencode/plans/multiplayer-migration.md` (see Decision 0 below)

---

## Problem Statement

The approved `multiplayer-migration.md` plan establishes ENet as the single game transport for all platforms, with GodotSteam layered on top for Steam-specific discovery, lobbies, and NAT traversal (SDR relay) in Phase 2. That plan assumed Steam and non-Steam players never need to be in the same session.

The actual requirement is **true crossplay**: a Steam player and a non-Steam (Epic/standalone) player must be able to join the exact same game session via a room code, with no manual IP sharing and no separate "Steam lobby" vs "standalone lobby" split.

Godot's `MultiplayerPeer` model only allows one active transport per `SceneTree` (`multiplayer.multiplayer_peer`). `SteamMultiplayerPeer` and `EOSMultiplayerPeer` are two separate, incompatible relay implementations — there is no built-in bridge between them. True crossplay therefore requires **all players, Steam included, to connect over a single shared transport**. Epic Online Services (EOS) is chosen as that shared transport because its P2P relay and Lobby system work independent of any specific platform, and it supports Steam identities as a login method — letting Steam players join transparently without creating a separate Epic account.

---

## Decision 0: Amendment to `multiplayer-migration.md`

The following decisions in the existing approved plan are **superseded**, not just extended:

| Existing Decision | Status | Replacement |
|---|---|---|
| Decision 2 diagram: "one ENet transport regardless of platform" | **Superseded** | One **EOS P2P transport** (via `EOSMultiplayerPeer`) regardless of platform. ENet is dropped project-wide, including the standalone/non-Steam path. |
| Decision 8: Standalone lobby with IP joining | **Superseded** | Room-code join via EOS Lobby search/join replaces manual IP entry for all non-Steam players. |
| Decision 9: Steam lobbies + Steam SDR relay for NAT traversal | **Superseded** | Steam is demoted to a **cosmetic/feature layer only** — achievements, overlay, friends list. Steam's own P2P networking and lobby system are **not used** for session transport or session discovery. |
| Decision 1 table (`GDSync` → built-in equivalents) | **Unchanged** | Still valid; only the underlying peer swaps from `ENetMultiplayerPeer` to `EOSMultiplayerPeer`. |
| Decisions 3, 4, 6, 7 (Spawner, Synchronizer, Scene Loading, RPC migration pattern) | **Unchanged in shape, unverified on new transport** | See Decision 6 below — must pass spike before being trusted on EOS transport. |
| "Out of Scope" — host migration | **At risk, needs explicit guard** | See Decision 9 below — EOS Lobby has its own owner-migration concept that must be suppressed to preserve "host disconnects → game ends." |

---

## Decision 1: Scope — EOS Alongside Steam, Not Replacing the Plan

EOS is added to solve **true crossplay**, which GodotSteam-only or ENet-only cannot provide. This is additive scope on top of the approved migration, not a rejection of it — the RPC/authority patterns, spawn model, and game systems (danger, round, quota, fishing) are unchanged in shape.

---

## Decision 2: EOS P2P as the Real Transport (not just lobby lookup)

Rejected: using EOS only for lobby discovery + NAT-assisted IP exchange, then falling back to raw `ENetMultiplayerPeer.create_client()`. That approach still inherits the ~30%-of-routers UPnP failure case from the existing plan, because EOS's NAT punch-through is part of its own P2P socket API and does not extend to unrelated raw ENet packets.

**Decision:** `EOSMultiplayerPeer` (EOS's P2P relay, with built-in NAT traversal) becomes the literal `multiplayer.multiplayer_peer` for every session. This is the only approach that satisfies "enter a room code, no IP hassle, reliably connects through NATs."

---

## Decision 3: Library — GD-EOS

No official Godot EOS SDK exists. Evaluated options:

| Library | Provides `EOSMultiplayerPeer`? | Maintenance |
|---|---|---|
| `3ddelano/epic-online-services-godot` (EOSG) | No (auth/achievements/leaderboards/lobbies focus) | Actively maintained, more popular |
| `Flying-Rat/GodotEOS` | No (achievements/leaderboards/auth focus) | Maintained |
| **`Daylily-Zeleen/GD-EOS`** | **Yes** — ships `EOSMultiplayerPeer`, credits EOSG's author for the underlying multiplayer mechanism | MIT, single maintainer, 37 stars, latest release v0.5.0 (Apr 2026). **README self-disclosed: "This repo is lack of testing. The name of APIs may be changed in later version."** |

**Decision:** GD-EOS, because it's the only option with a working `MultiplayerPeer` implementation. This is accepted as the single highest-risk dependency in the whole plan — a small, self-flagged-as-undertested, single-maintainer library sits underneath the entire networking stack.

---

## Decision 4: Steam Demoted to Feature Layer (no bridging of two transports)

Rejected approaches for combining Steam + EOS in one session:
- Custom bridge node relaying raw bytes between `SteamMultiplayerPeer` and `EOSMultiplayerPeer` sockets into a shared synthetic peer-ID space (genuine unsolved R&D — no known prior art).
- Hand-rolled packet routing replacing Godot's high-level multiplayer API entirely (throws away RPC/Spawner/Synchronizer for no reason).

**Decision:** All players — Steam included — connect via `EOSMultiplayerPeer`. GodotSteam is retained **only** for:
- Steam achievements
- Steam overlay
- Steam friends list (display only, not used for session discovery — see Decision 8)

Steam's own networking sockets, lobbies, and SDR relay are **not used**. This directly supersedes `multiplayer-migration.md` Decision 9.

**Clean-implementation note:** because this splits "Steam integration" into two disconnected concerns (achievements/cosmetics vs. transport), enforce that split at the file level, not just conceptually. All GodotSteam calls live in a new `systems/steam/steam_features.gd`, which is never imported by `NetworkManager`, `game_manager.gd`, or any RPC-bearing system. If a future change needs Steam code inside a networking file, that's a signal the boundary is being violated — treat it as a review flag, not a one-off exception.

---

## Decision 5: Steam Player Identity via EOS Connect

Since every player (Steam included) now authenticates through EOS to get a `ProductUserId` for `EOSMultiplayerPeer`, Steam players need a path into EOS that doesn't force a separate Epic account signup.

**Decision:** Use EOS Connect's Steam **External Credential Type**:
- Steam players: GodotSteam fetches a Steam auth session ticket → passed to `EOSConnect.login()` with External Credential Type `Steam`. Transparent, no Epic account required.
- Non-Steam players: Epic account login, or EOS's anonymous "Device ID" flow (`DEVICESSID_ACCESS_TOKEN`), also no forced account creation.

This is the only combination that preserves both "Steam achievements work" (Decision 4) and "frictionless room-code join" (Decision 2). No existing tutorial combines GodotSteam auth tickets with GD-EOS's `EOSConnect` bindings this way — this integration path will be assembled from EOS's general "Steam external credential" documentation plus GD-EOS's raw bindings.

**Clean-implementation note:** hide the Steam-vs-Epic-vs-device branching behind a single entry point, e.g. `NetworkManager.login() -> ProductUserId`. Callers (`lobby.gd`) never see EOS Connect internals or which credential path was used — all three branches live inside that one function, so the auth complexity has exactly one home instead of leaking into UI code.

---

## Decision 6: Verification Spike Before Touching Game Code

Every game system in the codebase (`game_manager.gd`, `spawn_manager.gd`, `player.gd`, `health_component.gd`, `danger_manager.gd`, `zone_manager.gd`, `round_manager.gd`, `rock_manager.gd`, `quota_manager.gd`, `coin_manager.gd`, `voice_chat_network.gd`) depends on Godot's standard `MultiplayerPeer` contract: `get_unique_id()`, `is_server()`, `peer_connected`/`peer_disconnected`, `get_remote_sender_id()`, and correct reliable/unreliable RPC delivery.

Given GD-EOS's self-disclosed lack of testing, this must be verified empirically before any production integration work begins.

**Spike scope (isolated test project, not the main game):**
1. Instantiate `EOSMultiplayerPeer` on two machines/processes, assign to `multiplayer.multiplayer_peer`.
2. Confirm `get_unique_id()`, `peer_connected`, `is_server()` behave identically to `ENetMultiplayerPeer`.
3. Confirm a basic `@rpc("any_peer")` call round-trips correctly.
4. **Confirm unreliable RPC channel behavior specifically** (`@rpc(..., "unreliable")`) — movement sync (`_sync_transform`) and voice (`send_voice_packet`) both depend on unreliable delivery not silently upgrading to reliable or dropping excessively.
5. **Confirm `MultiplayerSpawner` and `MultiplayerSynchronizer` work over `EOSMultiplayerPeer`** — these are separate Godot subsystems built on top of `MultiplayerPeer`, not just raw RPC, and are planned for use per the existing approved plan's Decisions 3–4. Must not assume RPC-level success implies these also work.

Only after this spike passes does full integration into `NetworkManager` and the game systems proceed.

---

## Decision 7: Room Codes via EOS Lobby Only

**Decision:** Room code = EOS Lobby ID/join code. `lobby.gd`'s join/create flow talks only to EOS's Lobby search/join API. Steam's own lobby API is not used for session discovery (Decision 4) — only for Steam overlay "friends list" display, which does not need to reflect actual joinable sessions in this phase.

Deferred: mirroring the EOS lobby ID into Steam lobby metadata so Steam's "invite friend" overlay button drops a friend directly into the right EOS lobby. Worth revisiting once room-code-only flow is working, if Steam-invite UX becomes a priority.

---

## Decision 8: SDK and Binary Distribution

The EOS C SDK cannot be redistributed (per GD-EOS's own README) and the GDExtension binary must be compiled locally against it.

**Decision:**
- `thirdparty/eos-sdk/` and the compiled GD-EOS addon directory are added to `.gitignore`, following the existing pattern already used for `addons/` (installed via Asset Library, not committed).
- AGENTS.md gets a new section documenting: where to download the EOS SDK, how to place it in `thirdparty/eos-sdk`, and the exact `scons` build command(s) for this project's target platform(s).
- Each development machine builds the GDExtension locally; no CI is currently in place for this project (per existing AGENTS.md conventions), so no build-fetch automation is needed at this time.

---

## Decision 9: Credential Storage

GD-EOS initialization requires `product_id`, `sandbox_id`, `deployment_id`, `client_id`, `client_secret`, and `encryption_key`. The latter two are secrets that must not enter git history.

**Decision:** Credentials load from an external config file (gitignored), read at runtime via `ConfigFile` or JSON — not hardcoded into any tracked `.gd`/`.tscn`/autoload. A `.gitignore`'d template file documents the expected keys for local setup.

**New requirement surfaced during review — test safety:** the autoload responsible for EOS init must **no-op gracefully** if the config file is missing or incomplete (e.g., a fresh clone, or the GUT headless test runner, which has no EOS credentials available). GUT tests (`--headless -s addons/gut/gut_cmdln.gd`) must not hard-fail or hang because EOS initialization was attempted without valid credentials.

**Clean-implementation note:** centralize this in one `EOSConfig` autoload that loads the config once at startup and exposes a single `EOSConfig.is_available: bool`. Every other system checks that one flag instead of scattering its own nil-checks or try/catch around missing credentials — one clear contract, one place the "is EOS usable right now" question gets answered.

---

## Decision 10: Host Disconnect / Lobby Ownership Guard

`multiplayer-migration.md`'s "Out of Scope" section explicitly excludes host migration — if the host disconnects, the game ends. EOS's Lobby system has its own built-in "lobby owner" concept and may attempt automatic owner reassignment on host disconnect.

**Decision:** Explicitly disable or ignore EOS Lobby's automatic owner-migration behavior (exact mechanism TBD during spike/integration — likely means not acting on EOS's lobby-owner-changed callback, and instead tearing down the session and returning all clients to the lobby screen exactly as the existing `_on_server_disconnected`/`_on_disconnected` handlers already do). Must verify during Decision 6's spike that EOS doesn't force a different behavior at the transport level independent of what the Lobby SDK does.

**Clean-implementation note:** isolate this into one explicit function, e.g. `_suppress_eos_lobby_migration()`, called once at lobby-create time, with a comment stating exactly why it exists (preserves the existing "host leaves → game ends" behavior from the approved plan's Out of Scope section). Keep this as one deliberate, documented call rather than scattered defensive checks against lobby-owner-changed signals throughout the codebase.

---

## Open Questions / Deferred Scope

- **Achievements/stats parity for non-Steam players.** User story #44 (from the existing plan) wants Steam achievements. EOS has its own Achievements/Stats API. Not yet decided whether Epic/non-Steam players get any progression system, or whether it's Steam-exclusive. **Needs a decision before shipping**, not before starting integration.
- **EOS sandbox certification for public release.** Epic gates sandboxes with player caps and feature restrictions before public launch (per general EOS documentation — not yet verified against this project's specific sandbox). Not a blocker for development/testing, but must be checked well before any Steam/Itch.io launch date.
- **Steam-invite-to-EOS-lobby bridging** (Decision 7 deferred item).

---

## Blocking Prerequisite

**Nothing in this plan is buildable yet.** An Epic Developer Portal product must be registered first: product, sandbox, deployment, and client credentials created, with **Peer2Peer**, **Lobby**, and **Connect** features enabled. This blocks Decision 6's spike and everything downstream of it.

---

## Migration Order

| Slice | Description | Blocked By |
|---|---|---|
| 0 | Register EOS product/sandbox/deployment/credentials in Epic Dev Portal | Nothing — do first |
| 1 | Set up GD-EOS: download SDK, compile GDExtension, gitignore per Decision 8 | Slice 0 |
| 2 | Verification spike (Decision 6) in isolated test project | Slice 1 |
| 3 | `NetworkManager` rewrite: EOS Connect login (Steam external credential + Epic/device fallback per Decision 5), EOS Lobby create/join/search replacing IP-based flow | Slice 2 passes |
| 4 | Swap `EOSMultiplayerPeer` in as `multiplayer.multiplayer_peer`; re-verify `game_manager.gd`, `spawn_manager.gd`, all `@rpc` game systems against real EOS sessions | Slice 3 |
| 5 | GodotSteam integration for achievements/overlay/friends only (no networking) | Slice 4 (or parallel, since independent) |
| 6 | Host-disconnect / lobby-ownership guard verification (Decision 10) | Slice 4 |
| 7 | Credential loading + test-safety no-op guard (Decision 9) | Can start anytime, needed before Slice 2 test runs |
