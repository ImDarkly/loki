# EOSG Transport Spike (`tests/eosg_spike/`)

Scaffolds and verifies Epic Online Services (EOSG plugin v2.3.0) transport and P2P connection handshake.

## Usage

**Host:**
```powershell
& "E:\Godot\Godot_v4.6.2-stable_win64.exe" --path . --scene res://tests/eosg_spike/eosg_spike.tscn -- --role=host --room-code=test1 --credential-name=host_user
```

**Client:**
```powershell
& "E:\Godot\Godot_v4.6.2-stable_win64.exe" --path . --scene res://tests/eosg_spike/eosg_spike.tscn -- --role=client --room-code=test1 --credential-name=client_user
```

## Acceptance Criteria (5/5)
1. Dev Auth Tool login successful (`EOSAuth`).
2. EOS Connect login successful (`EOSConnect`).
3. Multiplayer peer created successfully (`EOSMultiplayerPeer`).
4. `get_unique_id()` non-zero and `is_server()` correctly set per role.
5. `peer_connected` signal fires successfully upon P2P connection.

## Rollback / Abort Criteria
If later EOSG verification slices stall (~2 days no concrete progress on a specific failing item), abort EOSG migration:
1. Shelve `feat/eosg-transport-spike`.
2. Restore GD-EOS as production transport (`feat/eos-transport-spike`).
3. Fix remaining GD-EOS gaps (`MultiplayerSpawner`, `peer_connection_closed`).
