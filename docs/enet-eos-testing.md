# EOS vs ENet in testing

Production multiplayer is EOS-only: `autoloads/network_manager.gd`
`host_game`/`join_game` via `EOSGMultiplayerPeer` + `HLobbies`
(host ~lines 102-133, join ~lines 160-176). Autoloads in
`project.godot:22-30`.

Game code (`entities/player/player.gd`, e.g. lines 787, 948, 967, 1001)
only branches on generic `multiplayer.*`
(`has_multiplayer_peer` / `is_server` / `get_unique_id`), so any
`MultiplayerPeer` works.

GUT tests use `ENetMultiplayerPeer` as a headless double because EOS
needs login/lobby/cloud and can't run headless.

- Full handshake (`tests/unit/test_player.gd:365-435`, 5 tests, ports
  37877-37881 and 37897-37901, bounded 120-frame loops) is only needed
  for RPC round-trip asserts.
- Simple client-noop tests instantiate `ENetMultiplayerPeer` and call `peer.create_client(...)` with no
  handshake (`test_quota_manager.gd:40`, `test_danger_manager.gd:382`,
  etc.).

Timeout cause: loops are bounded, but on port conflict / `TIME_WAIT`
the handshake never satisfies `get_unique_id != 1` + `get_peers`, so it
spins the full 120+120 frames per test; headless throttling worsens it.
Quick runs: `-gtest=test_player.gd` only, or skip the 5 round-trip tests.
