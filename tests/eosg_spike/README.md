# EOSG Transport Spike & RPC Verification (`tests/eosg_spike/` / `tests/eos_spike/`)

Scaffolds and verifies Epic Online Services (EOSG plugin v2.3.0) transport, P2P connection handshake, Reliable / Unreliable `@rpc` communication, and Godot built-in `MultiplayerSpawner` / `MultiplayerSynchronizer` over `EOSGMultiplayerPeer`.

## Environment Note (verified 2026-08-03)

The spike runs against EOSG's **High-Level API** (`HPlatform.setup_eos_async` + `HAuth.login_devtool_async` / `HAuth.login_anonymous_async`). This requires:
- GD-EOS's native `EOS` class must be **disabled** (remove `res://addons/gd-eos/gd-eos.gdextension` from `.godot/extension_list.cfg`) — otherwise GD-EOS's `EOS`/`EOSPlatform`/`EOSConnect` shadow EOSG's `class_name EOS` wrapper and the wrapper fails to parse.
- EOSG autoloads registered in `project.godot` `[autoload]`: `EOSGRuntime`, `HPlatform`, `HAuth` (mirrors `addons/epic-online-services-godot/plugin.gd`).

## Export Packaging Note (verified 2026-08-02)

`include_filter` must be **empty** (`include_filter=""`), not `addons/epic-online-services-godot/bin/*`. Godot's built-in `GDExtensionExportPlugin` already ships the plugin's `.dll` plus its declared `[dependencies]` (`EOSSDK-Win64-Shipping.dll`, `xaudio2_9redist.dll`) as flat shared objects next to the exported exe. Adding the `bin/*` glob to `include_filter` instead embeds `libeosg*.dll` inside the PCK, which makes `FileAccess::exists()` succeed on the `res://` path and defeats Windows' executable-directory library fallback — producing `Error 126: The specified module could not be found` at startup.

## Usage

### Mode 1: Device ID Login (Recommended for Multi-Device / Separate Machines)
*Does not require running the Dev Auth Tool server.*

**1. Host (Device A):**
```powershell
& "C:\Godot\Godot_v4.6.2-stable_win64.exe" --path . --scene res://tests/eosg_spike/eosg_spike.tscn -- --role=host --room-code=test1 --auth-mode=device_id
```
*(Copy the printed `ProductUserId`, e.g. `0002b85f889b4c7b94c99a00b8c04da8`)*

**2. Client (Device B):**
Pass the host's ProductUserId directly via `--host-puid`:
```powershell
& "C:\Godot\Godot_v4.6.2-stable_win64.exe" --path . --scene res://tests/eosg_spike/eosg_spike.tscn -- --role=client --room-code=test1 --auth-mode=device_id --host-puid=0002b85f889b4c7b94c99a00b8c04da8
```

### Mode 2: Dev Auth Tool (Local / Same-Machine or Network IP)

**Host:**
```powershell
& "C:\Godot\Godot_v4.6.2-stable_win64.exe" --path . --scene res://tests/eosg_spike/eosg_spike.tscn -- --role=host --room-code=test1 --credential-name=host_user --dev-auth-host=localhost:4545
```

**Client:**
```powershell
& "C:\Godot\Godot_v4.6.2-stable_win64.exe" --path . --scene res://tests/eosg_spike/eosg_spike.tscn -- --role=client --room-code=test1 --credential-name=client_user --dev-auth-host=192.168.x.x:4545
```

## Acceptance Criteria (9/9)
1. EOS Login successful (Dev Auth or Device ID).
2. EOS Connect login successful (`EOSConnect`).
3. Multiplayer peer created successfully (`EOSMultiplayerPeer`).
4. `get_unique_id()` non-zero and `is_server()` correctly set per role.
5. `peer_connected` signal fires successfully upon P2P connection.
6. **Reliable `@rpc` test:** all sent messages received (10/10), in order, no duplicates.
7. **Unreliable `@rpc` test:** messages delivered (60/60) with tracked round-trip latency.
8. **MultiplayerSpawner test:** one `spawnable_marker.tscn` spawned per connected peer, replicated to host & client.
9. **MultiplayerSynchronizer test:** `position` Vector3 replicated between peers via built-in synchronizer.

## Results Table

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

*Same-machine run (host `host_user` + client `client_user`, Dev Auth Tool, 2026-08-03): all 9/9 criteria passed. Cross-device run still pending a second physical machine.*

## Rollback / Abort Criteria
If later EOSG verification slices stall (~2 days no concrete progress on a specific failing item), abort EOSG migration:
1. Shelve `feat/eosg-transport-spike`.
2. Restore GD-EOS as production transport (`feat/eos-transport-spike`).
3. Fix remaining GD-EOS gaps (`MultiplayerSpawner`, `peer_connection_closed`).
