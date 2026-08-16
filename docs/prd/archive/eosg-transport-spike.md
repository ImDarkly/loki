**Feature ID:** EOSG-SPIKE-001

**Status:** Slices 1–3 CLOSED — same-machine 9/9 verified (2026-08-03); cross-device export run deferred

**Owner:** Solo Developer

**Tech Stack:** Godot 4.6, GDScript, EOSG plugin v2.3.0 (`3ddelano/epic-online-services-godot`), `EOSGMultiplayerPeer`

**Supersedes/Amends:** `docs/prd/eos-crossplay.md` Decision 6 spike scope (transport candidate: GD-EOS → EOSG)

---

## Problem Statement

`docs/prd/eos-crossplay.md` Decision 6 requires an empirical verification spike before any production networking code touches EOS. The original spike (`tests/eos_spike/`, GD-EOS) passed RPC-level checks but surfaced two unresolved gaps: `MultiplayerSpawner` returned `null` (broken spawn replication) and `peer_connection_closed` had a signal-arity mismatch. GD-EOS is a self-flagged as undertested, single-maintainer dependency.

EOSG (`3ddelano/epic-online-services-godot`) was selected as the replacement transport candidate. It ships `EOSGMultiplayerPeer` (credited by GD-EOS's author as the source of GD-EOS's multiplayer mechanism), is actively maintained, and is the more popular library. This plan verifies the full Godot `MultiplayerPeer` contract surface on EOSG — including the two subsystems GD-EOS failed — before committing to the migration.

## Solution

A three-slice verification spike in an isolated test project (`tests/eosg_spike/`), mirroring the original GD-EOS spike's interface (`--role=host/client --room-code=X`) so results are directly comparable. EOSG-specific API calls are confined to auth and peer-setup boilerplate; all acceptance criteria are exercised through Godot's transport-agnostic `multiplayer.*` / `@rpc` API surface.

## User Stories

1. As a developer, I want to know whether `EOSGMultiplayerPeer` satisfies Godot's standard `MultiplayerPeer` contract (`get_unique_id()`, `is_server()`, `peer_connected`, reliable/unreliable RPC delivery) so I can decide whether EOSG replaces GD-EOS as the EOS transport.
2. As a developer, I want to know whether `MultiplayerSpawner` spawns and replicates nodes correctly over EOSG so the game's spawn model (per the approved migration plan's Decision 3) is trustworthy.
3. As a developer, I want to know whether `MultiplayerSynchronizer` replicates properties over EOSG so synchronized state (positions, gameplay state) works.
4. As a developer, I want the packaged export to run cross-device without "GDExtension dynamic library not found" so players on separate machines can actually connect.
5. As a developer, I want results recorded in a pass/fail table comparable to the GD-EOS spike's, so the decision between EOSG and GD-EOS is evidence-based.

---

## Slice Breakdown

### Slice 1 — EOSG Spike Scaffold & Auth (issue #139, CLOSED)

Install EOSG via the Godot Asset Library at a pinned release tag (v2.3.0), enable the plugin (EOSG ships `plugin.cfg`, unlike GD-EOS's auto-loading `.gdextension`), and fix the `export_presets.cfg` packaging. Scaffold `tests/eosg_spike/` with:
- Epic Dev Auth Tool auth path (standalone — does not reuse `autoloads/eos_manager.gd`)
- Credentials sourced from `eos_credentials.cfg` (`PRODUCT_ID`, `SANDBOX_ID`, `DEPLOYMENT_ID`, `CLIENT_ID`, `ENCRYPTION_KEY`; field-name mapping to EOSG's credential struct confirmed empirically)
- `--role=host/client --room-code=X` CLI args
- Peer connection through `EOSGMultiplayerPeer`
- Verify `get_unique_id()` non-zero + distinct per peer, `peer_connected` fires on both sides, `is_server()` correct per role

Also: rollback/abort criteria documented in the spike README — if later slices stall (~2 focused days on a failing item), shelve `feat/eosg-transport-spike`, restore GD-EOS, fix GD-EOS's two gaps instead. Fallback path (checkout `feat/eos-transport-spike`) confirmed operational.

### Slice 2 — RPC Verification (issue #140, CLOSED)

Extend `tests/eosg_spike/` with reliable + unreliable `@rpc` routines using only built-in annotations:
- Reliable: N messages client→host, all received, in order, no duplicates (baseline: GD-EOS 10/10)
- Unreliable: N messages at high frequency, delivery rate + round-trip latency tracked (baseline: GD-EOS 60/60, ~50ms)
- Results in pass/fail table format for direct comparison

### Slice 3 — Spawner & Synchronizer Verification (issue #141, CLOSED)

Extend `tests/eosg_spike/` with the two subsystems GD-EOS failed:
- `MultiplayerSpawner`: spawn one `spawnable_marker.tscn` instance per connected peer (mirroring the GD-EOS spike structure), replicated to host & client
- `MultiplayerSynchronizer`: replicate a Vector3 `position` property between peers
- Verify the export packaging fix end-to-end: build export, run on two physical devices, confirm no "GDExtension dynamic library not found"

---

## Acceptance Criteria

### Slice 1 (CLOSED — all met, one correction)
- [x] EOSG installed at pinned release tag, plugin enabled
- [x] `export_presets.cfg` packaging fixed — `include_filter=""` (empty), NOT `bin/*`; the GDExtension export plugin ships lib + `[dependencies]` as flat shared objects next to the exe, and including `bin/*` embeds the lib in the PCK which breaks the executable-directory library fallback (Windows Error 126). Verified 2026-08-02 on `build/Chum.exe`.
- [x] `tests/eosg_spike/` scaffolded with standalone Dev Auth auth path
- [x] `--role=host/client --room-code=X` CLI interface implemented and tested
- [x] Two instances authenticate and establish peer connection via `EOSGMultiplayerPeer`
- [x] `get_unique_id()` returns distinct non-zero values per peer
- [x] `peer_connected` fires on both host and client
- [x] `is_server()` correctly reports host=true, client=false
- [x] Rollback/abort criteria documented; fallback path confirmed working

### Slice 2 (CLOSED — all met)
- [x] Reliable `@rpc`: all sent received, in order, no duplicates (10/10)
- [x] Unreliable `@rpc`: messages delivered, latency tracked (60/60, ~50ms avg)
- [x] Results recorded in pass/fail table format

### Slice 3 (CLOSED — same-machine 9/9 verified; cross-device run deferred)
- [x] `MultiplayerSpawner` spawns one node per connected peer on both host and client
- [x] `MultiplayerSynchronizer` replicates a property between peers correctly
- [x] Results recorded in the pass/fail table (same-machine run 2026-08-03: 9/9)
- [ ] Export build with updated `include_filter` runs across two physical devices without "GDExtension dynamic library not found" (deferred — no second device)
- [ ] All 5 acceptance items pass on a cross-device run (deferred)

---

## Pass/Fail Results Table

| Test Item | Pass/Fail | Notes / Metrics |
|---|---|---|
| EOS Login (Device ID / Dev Auth) | PASS | Successfully authenticated with EOS |
| EOS Connect Login | PASS | EOSConnect login established ProductUserId |
| EOSMultiplayerPeer Creation | PASS | Multiplayer peer created and assigned |
| Multiplayer Unique ID & Server Status | PASS | get_unique_id non-zero, is_server correct |
| peer_connected Signal | PASS | P2P handshake established between peers |
| Reliable RPC Test (10/10) | PASS | 10/10 received, in order, 0 duplicates |
| Unreliable RPC Test (60/60) | PASS | 60/60 delivered, avg latency ~66ms |
| MultiplayerSpawner Test (per peer) | PASS | 1 marker per peer, host & client both saw it |
| MultiplayerSynchronizer Test (Vector3) | PASS | position (42,0,0) replicated to client |

*Same-machine run (host `host_user` + client `client_user`, Dev Auth Tool, 2026-08-03): all 9/9 criteria passed. Cross-device run deferred until a second physical device is available. Slices 1–2 results were recorded under GD-EOS coexisting with EOSG; slice 3 was verified with GD-EOS disabled (see README "Environment Note").*

---

## Rollback / Abort Criteria

If later EOSG verification slices stall (~2 days no concrete progress on a specific failing item), abort EOSG migration:
1. Shelve `feat/eosg-transport-spike`.
2. Restore GD-EOS as production transport (`feat/eos-transport-spike`).
3. Fix remaining GD-EOS gaps (`MultiplayerSpawner`, `peer_connection_closed`).

---

## Open Questions / Deferred

- **Cross-device run logistics.** The slice 3 acceptance criteria require two physical devices. Same-machine host+client (Dev Auth or device_id mode) verifies the protocol; the two-device run may be deferred until a second device is available.
- **GD-EOS removal (#142, OPEN).** After slice 3 passes, GD-EOS (`tests/eos_spike/`, `feat/eos-transport-spike`) is slated for removal; decision tracked separately.

---

## Blocking Prerequisite

EOS product/sandbox/deployment/client credentials in Epic Dev Portal with **Peer2Peer**, **Lobby**, and **Connect** features enabled (per `eos-crossplay.md`). `eos_credentials.cfg` (a non-dotfile so it ships inside the embedded PCK — Godot's exporter never includes dotfiles like `.env`). Slice 3 blocked by RPC Verification (#140) — closed.
