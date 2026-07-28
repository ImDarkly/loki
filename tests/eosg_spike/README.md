# EOSG Transport Spike (`tests/eosg_spike/`)

Scaffolds and verifies Epic Online Services (EOSG plugin v2.3.0) transport and P2P connection handshake.

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

## Acceptance Criteria (5/5)
1. EOS Login successful (Dev Auth or Device ID).
2. EOS Connect login successful (`EOSConnect`).
3. Multiplayer peer created successfully (`EOSMultiplayerPeer`).
4. `get_unique_id()` non-zero and `is_server()` correctly set per role.
5. `peer_connected` signal fires successfully upon P2P connection.

## Rollback / Abort Criteria
If later EOSG verification slices stall (~2 days no concrete progress on a specific failing item), abort EOSG migration:
1. Shelve `feat/eosg-transport-spike`.
2. Restore GD-EOS as production transport (`feat/eos-transport-spike`).
3. Fix remaining GD-EOS gaps (`MultiplayerSpawner`, `peer_connection_closed`).
