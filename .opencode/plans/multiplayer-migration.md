## GD-Sync to Godot ENet + Voice Migration

**Version:** 1.0
**Date:** July 7, 2026
**Status:** APPROVED FOR DEVELOPMENT
**Owner:** Solo Developer

---

## Problem Statement

The game currently depends on GD-Sync for all multiplayer functionality (lobby management, RPC, property synchronization, scene management, player identity). The GD-Sync connection fails with an invalid public key error, and the service requires paid API keys with data transfer limits. The project needs to replace GD-Sync with a free, self-sufficient networking stack that works on Steam (with full social features) and non-Steam platforms (Itch.io demo, standalone builds) without ongoing service costs or external server dependencies.

The current voice system (VoiceChatManager) is already decoupled from GD-Sync — it monitors local microphone amplitude with hysteresis. What's missing is networked voice transmission (players talking to each other over the internet).

---

## Solution

Replace GD-Sync with **Godot's built-in ENetMultiplayerPeer** for game transport, **@rpc annotations** for remote calls, **MultiplayerSpawner + MultiplayerSynchronizer** for player replication, and the **godot-voip** addon for networked voice chat. The Steam release adds **GodotSteam** on top for lobbies, invites, and friends integration. Non-Steam builds use a simple "join by IP" flow with optional UPnP.

The key architectural principle: **one game session transport (ENet) regardless of platform**. Platform-specific layers only handle discovery (how players find the host's IP/Steam lobby). The actual gameplay networking is identical everywhere.

---

## User Stories

### Lobby & Connection

1. As a **host**, I want to **host a game session on my PC**, so that **friends can connect to me as a listen-server**
2. As a **host**, I want to **see my public IP address displayed**, so that **I can share it with friends on non-Steam builds**
3. As a **host**, I want to **use UPnP to auto-forward the game port**, so that **I don't need manual router configuration**
4. As a **friend**, I want to **enter a host's IP address to join their game**, so that **I can play on non-Steam builds**
5. As a **Steam player**, I want to **create a Steam lobby**, so that **friends can join via Steam invites and overlay**
6. As a **Steam player**, I want to **join a friend's game through Steam invite**, so that **I don't need to manually enter IP addresses**
7. As a **player**, I want to **see a list of connected players in the lobby**, so that **I know who is in the game**
8. As a **player**, I want to **see the host's name**, so that **I know who to coordinate with**
9. As a **host**, I want to **start the game when all players are ready**, so that **everyone loads in together**
10. As a **player**, I want to **be notified when the host starts the game**, so that **I know the session is beginning**
11. As a **player**, I want to **see a connection status indicator**, so that **I know if I'm connected or not**
12. As a **Steam player**, I want to **close/lock the lobby**, so that **nobody else joins mid-game**

### Player Identity & Authority

13. As a **player**, I want to **have a unique player ID**, so that **the game can distinguish between players**
14. As a **host**, I want to **be recognized as the server authority**, so that **I can validate game logic**
15. As a **player**, I want to **control only my own character**, so that **I don't accidentally move others**
16. As a **player**, I want to **see my own player name and others' names**, so that **I know who is who**
17. As a **new player**, I want to **receive the current game state when I join late**, so that **I'm synchronized with everyone**

### Gameplay Networking

18. As a **player**, I want to **see other players' positions and rotations updated in real-time**, so that **I know where everyone is**
19. As a **player**, I want to **see other players' fishing state (casting, waiting, reeling)**, so that **I understand what the team is doing**
20. As a **player**, I want to **see other players' cast target positions**, so that **I know where they are fishing**
21. As a **host**, I want to **verify game-critical logic (danger spawning, quota changes) on my machine**, so that **the game state is authoritative**
22. As a **player**, I want to **receive danger event notifications synchronously**, so that **everyone sees the shark at the same time**
23. As a **player**, I want to **report my catch to the host**, so that **the team quota updates correctly**
24. As a **player**, I want to **see the updated team quota after a catch**, so that **progress is visible**
25. As a **player**, I want to **see other players' yelling states**, so that **I know who is scaring fish away**
26. As a **player**, I want to **know when a fish escapes because someone yelled**, so that **I understand the causation**
27. As a **player**, I want to **be spawned into the game world when I connect**, so that **I can start playing immediately**
28. As a **player**, I want to **despawn cleanly when I disconnect**, so that **no ghost players remain**

### Scene Management

29. As a **host**, I want to **load the main game scene for all players**, so that **everyone transitions together**
30. As a **player**, I want to **receive a "loading scene" notification**, so that **I know the game is transitioning**
31. As a **player**, I want to **confirm when I've finished loading the new scene**, so that **the host knows everyone is ready**
32. As a **player**, I want to **return to the lobby after a game ends**, so that **we can play again**

### Voice Chat

33. As a **player**, I want to **speak into my microphone and have other players hear me**, so that **we can communicate**
34. As a **player**, I want to **hear other players' voices in real-time**, so that **coordination is natural**
35. As a **player**, I want to **my active voice transmission to trigger the yelling detection**, so that **yelling has a gameplay consequence**
36. As a **player**, I want to **voice data to travel over the same ENet connection**, so that **no separate voice server is needed**
37. As a **player**, I want to **see a push-to-talk or voice activity indicator**, so that **I know when I'm transmitting**
38. As a **player**, I want to **adjust my mic input threshold**, so that **the game detects my voice correctly**

### Steam Integration

39. As a **Steam player**, I want to **initialize Steam when the game launches**, so that **I can use Steam features**
40. As a **Steam player**, I want to **see my Steam friends in the lobby UI**, so that **I can easily invite them**
41. As a **Steam player**, I want to **receive a Steam invite notification**, so that **I can join a friend's game**
42. As a **Steam player**, I want to **use Steam's relay network for NAT traversal**, so that **I can connect even on strict networks**
43. As a **Steam player**, I want to **have my Steam display name shown in-game**, so that **my identity is consistent**
44. As a **Steam player**, I want to **unlock Steam achievements for in-game milestones**, so that **there's meta-game progression**
45. As a **Steam player**, I want to **use Steam Remote Play Together**, so that **I can play with friends who don't own the game**

### Licensing & Distribution

46. As a **developer**, I want to **remove all GD-Sync dependencies from the codebase**, so that **there are no ongoing service costs or API key issues**
47. As a **developer**, I want to **ship one build that works on both Steam and Itch.io**, so that **I maintain a single codebase**
48. As a **developer**, I want to **the non-Steam build to use simple IP-based joining**, so that **no relay server is needed**
49. As a **developer**, I want to **the Steam build to detect Steam and use Steamworks features automatically**, so that **I don't need separate build configurations**

---

## Implementation Decisions

### Architecture Overview

The game uses a **listen-server** model: the host's PC acts as both the game server and a player. One ENet transport handles all game networking (RPCs, replication, voice). A platform-detection layer at startup selects the discovery path:

```
Game Client
├── Platform Detector (Steam running? -> Steam stack, else -> Standalone stack)
├── Lobby Manager
│   ├── Steam path:  Steamworks lobbies (invites, friends, SDR relay)
│   └── Standalone:  Join by IP (UPnP auto-forward, manual IP sharing)
├── ENet Network Manager
│   ├── Host:   ENetMultiplayerPeer.create_server(PORT, MAX_CLIENTS)
│   ├── Client: ENetMultiplayerPeer.create_client(IP, PORT)
│   ├── @rpc RPC system             (replaces GDSync.call_func_all)
│   ├── MultiplayerSpawner          (replaces GDSync.multiplayer_instantiate)
│   └── MultiplayerSynchronizer     (replaces GDSync PropertySynchronizer)
├── Game Systems (danger, round, quota, fishing)
│   └── multiplayer.is_server()     (replaces GDSync.is_host())
└── Voice Chat
    ├── godot-voip VoiceOrchestrator (networked voice over ENet)
    └── Existing VoiceChatManager    (local mic amplitude, unchanged)
```

### Decision 1: Replace GD-Sync Autoload with Built-in Multiplayer

Remove the `GDSync` autoload from `project.godot`. Replace all `GDSync.*` calls with Godot built-in equivalents:

| GD-Sync | Replacement |
|---|---|
| `GDSync.start_multiplayer()` | `ENetMultiplayerPeer.create_server()` / `create_client()` |
| `GDSync.is_host()` | `multiplayer.is_server()` |
| `GDSync.get_client_id()` | `multiplayer.get_unique_id()` |
| `GDSync.player_set_username()` | Custom player info dict, synced on peer connect |
| `GDSync.player_get_username()` | Read from local player info dict |
| `GDSync.connected` | `multiplayer.peer_connected` / `multiplayer.connected_to_server` |
| `GDSync.connection_failed` | `multiplayer.connection_failed` |
| `GDSync.disconnected` | `multiplayer.peer_disconnected` / `multiplayer.server_disconnected` |
| `GDSync.lobby_created` | Custom signal or Steam `lobby_created` |
| `GDSync.lobby_creation_failed` | Custom signal or Steam `lobby_creation_failed` |
| `GDSync.lobby_joined` | Custom signal or Steam `lobby_joined` |
| `GDSync.lobby_join_failed` | Custom signal or Steam `lobby_join_failed` |
| `GDSync.lobby_data_changed` | Custom signal (`player_list_changed` already exists) |
| `GDSync.client_joined` | `multiplayer.peer_connected` |
| `GDSync.client_left` | `multiplayer.peer_disconnected` |
| `GDSync.change_scene_called` | Custom signal + `SceneTree.change_scene_to_file()` with ready checks |
| `GDSync.change_scene()` | Host calls `rpc("load_scene")` -> clients load -> confirm ready -> start |
| `GDSync.lobby_create()` | Steam: `Steam.createLobby()`. Standalone: no-op (host just starts server) |
| `GDSync.lobby_join()` | Steam: `Steam.joinLobby()`. Standalone: `create_client(IP, PORT)` |
| `GDSync.lobby_set_data()` | Steam: `Steam.setLobbyData()`. Standalone: local dict |
| `GDSync.lobby_get_data()` | Steam: `Steam.getLobbyData()`. Standalone: local dict |
| `ENUMS.LOBBY_CREATION_ERROR.LOBBY_ALREADY_EXISTS` | Custom error handling |
| `GDSync.expose_func(func)` | `@rpc` annotation on the function |
| `GDSync.call_func_all(callable, args)` | `func.rpc(args)` (with `@rpc("call_local")`) |
| `GDSync.call_func(callable, args)` | `func.rpc_id(target_id, args)` |
| `GDSync.multiplayer_instantiate()` | `MultiplayerSpawner.spawn()` |
| `GDSync.set_gdsync_owner()` | `node.set_multiplayer_authority(peer_id)` |
| `PropertySynchronizer` (tscn nodes) | `MultiplayerSynchronizer` (built-in Godot nodes) |

### Decision 2: Architecture: Platform Detection at Runtime

A single `NetworkManager` autoload (replacing GD-Sync as the networking entry point) detects the platform on startup:

```gdscript
func _ready():
    if Steam.is_steam_running():
        _use_steam = true
        Steam.steamInit()
    else:
        _use_steam = false
```

This check happens once. All downstream code branches on `_use_steam` for discovery/lobby operations, but uses identical ENet transport for gameplay.

**Steam path flow:**
1. Host: `Steam.createLobby()` -> Steam lobby created -> start ENet server -> lobby data includes host's ENet IP
2. Client: Receives invite -> `Steam.joinLobby()` -> reads lobby data -> `ENetMultiplayerPeer.create_client(IP, PORT)`

**Standalone path flow:**
1. Host: Start ENet server -> attempt UPnP forward -> fetch public IP from `api.ipify.org` -> display IP in UI
2. Client: Enter IP in text field -> `ENetMultiplayerPeer.create_client(IP, PORT)`

### Decision 3: Player Spawning with MultiplayerSpawner

Replace `GDSync.multiplayer_instantiate()` with Godot's `MultiplayerSpawner` node in the main game scene. The spawner path points to a `Players` node container. The player scene is added to the spawner's auto-spawn list.

The host spawns a player for each connected peer:
- Host's own player: spawned immediately on game start
- Joining players: spawned in `multiplayer.peer_connected`
- Authority set to the peer ID so each client controls their own character

### Decision 4: Property Synchronization with MultiplayerSynchronizer

Replace the 4 GD-Sync PropertySynchronizer nodes in `player.tscn` with native `MultiplayerSynchronizer` nodes:

| Property | Sync Node | Properties | Interval | Interpolation |
|---|---|---|---|---|
| Body transform | MultiplayerSynchronizer | `global_position`, `rotation` | 30 Hz | Yes |
| Head rotation | MultiplayerSynchronizer | `rotation` (on Head node) | 30 Hz | Yes |
| Fishing state | MultiplayerSynchronizer | `current_state` (on FishingMechanic) | 10 Hz | No |
| Cast target | MultiplayerSynchronizer | `cast_target_position` (on FishingMechanic) | 10 Hz | No |

The `is_yelling` property is NOT synced via a synchronizer — it is sent as a targeted unreliable RPC from the owning client to all other peers whenever the state changes.

### Decision 5: Voice Chat with godot-voip

Replace the currently unused GD-Sync VoiceChat proximity audio with the **godot-voip** addon (`VoiceOrchestrator` node). Voice data travels over the existing ENet connection — no separate voice server needed.

**Integration points:**
- The `VoiceOrchestrator` node is added to the game scene and connected to the existing `ENetMultiplayerPeer`
- The existing `VoiceChatManager` (mic amplitude detection) remains unchanged and drives `is_yelling`
- The `is_yelling` flag is sent as a targeted unreliable RPC from each client to all peers whenever it changes
- Voice input is independent of yelling detection: the mic is always open (or push-to-talk) for communication, while yelling detection runs in parallel

### Decision 6: Scene Loading

Replace `GDSync.change_scene()` with a host-driven load flow:
1. Host calls `SceneTree.change_scene_to_file()` locally
2. Host sends `rpc("load_scene", path)` to all clients
3. Clients load the scene asynchronously
4. Each client sends `rpc_id(1, "scene_loaded")` when done
5. Host waits for all clients, then starts the game

Use a `scene_loaded` counter to track readiness. The lobby scene has a simple loading UI.

### Decision 7: Game Systems — RPC Migration

The four game systems that use GD-Sync RPCs (danger, round, quota, fishing) follow a consistent migration pattern:

**Before (GD-Sync):**
```gdscript
func _ready():
    GDSync.expose_func(_apply_synced_state)

func apply_state(data):
    if not GDSync.is_host(): return
    _apply_synced_state(data)
    GDSync.call_func_all(_apply_synced_state, data)
```

**After (Built-in):**
```gdscript
@rpc("call_local", "reliable", "authority")
func apply_state(data):
    if not multiplayer.is_server(): return
    _apply_synced_state(data)
    apply_state.rpc(data)
```

The `@rpc("authority")` ensures only the server can call it. `"call_local"` ensures the host also executes it locally. Clients receive it as a remote call.

Targeted RPCs (like `fishing_mechanic.gd` reporting a catch to the host) use:
```gdscript
@rpc("any_peer", "call_remote", "reliable")
func report_catch(amount: int):
    if not multiplayer.is_server(): return
    _process_catch(amount)
```

### Decision 8: Standalone Lobby with IP Joining

The lobby scene maintains its current flow for standalone builds but removes GD-Sync lobby API calls:
- Create game: host starts ENet server, shows IP, shares via clipboard
- Join game: enter IP, connect as client
- Player list: built from `multiplayer.peer_connected` / `peer_disconnected` signals
- Start game: host-only button that triggers scene load RPC to all clients

The existing `game_manager.gd` autoload continues to track the player list but uses `multiplayer.peer_connected`/`peer_disconnected` instead of GD-Sync lobby signals.

### Decision 9: Steam Integration (Phase 2 — After Migration)

Added after the core migration is complete and tested:
- GodotSteam plugin (GDExtension)
- Steam lobby creation / joining / invites
- Steam display name as player name
- Steam achievements
- Steam SDR relay for NAT traversal
- Steam Voice as an alternative voice transport option

The Steam integration is additive — it wraps the existing ENet transport with a better discovery layer. The core game networking never touches Steam APIs.

### Decision 10: Remove GD-Sync Plugin

After migration, completely remove the addon:
1. Delete `addons/GD-Sync/` directory and all contents
2. Remove `GDSync="*uid://bt6tf85hp7w1"` from `project.godot` autoloads
3. Remove `[GD-Sync]` section from `project.godot` (API keys, version)
4. Remove `res://addons/GD-Sync/plugin.cfg` from `editor_plugins`

---

## Testing Decisions

### What makes a good test

Tests should verify external behavior (signals emitted, state transitions, correct data flow) — not implementation details (which multiplayer API is called). After migration, game logic tests should be identical in structure to current GD-Sync-era tests since the game systems don't change — only the networking layer changes.

### Existing test adaptation

The existing GUT tests for game systems need minimal changes because they test game logic in isolation:

| Test File | Change Required | Rationale |
|---|---|---|
| `test_danger_manager.gd` | Replace `GDSync.is_host()` checks with `multiplayer.is_server()` (defaults to `false` in tests) | Same test structure, same game logic assertions |
| `test_round_manager.gd` | Same as above | Already has a conditional `GDSync.is_host()` check on line 42 — adapt to built-in API |
| `test_quota_manager.gd` | Same pattern | Quota logic tested independently of transport |
| `test_fishing_mechanic.gd` | Same pattern | Fishing state machine tested with direct calls |
| `test_voice_chat_manager.gd` | No changes needed | Zero GD-Sync dependency already |
| `test_player.gd` | Minimal or no changes | `is_yelling` polling unchanged |

### New tests needed

| Test Area | What to Test | Approach |
|---|---|---|
| Lobby Manager | Host creates lobby, client joins, player list syncs | Two `ENetMultiplayerPeer` instances in same process (local server + client) |
| Scene Loading | Host triggers scene change, clients load and confirm | Same two-peer setup, verify loading sequence |
| Spawn Manager | MultiplayerSpawner spawns player per connected peer | Spawn + verify node count, authority assignment |
| Voice Chat Integration | VoiceOrchestrator connects to existing ENet peer | Verify node added to tree, recording toggles correctly |

### Testing prior art

The project's existing tests follow the GUT pattern: instantiate real scenes, connect signals, manipulate state, assert outcomes. The two-peer lobby test is a new pattern but follows the same philosophy — instantiate real networking objects and observe their signals.

---

## Out of Scope

- **Dedicated server mode** — all games are listen-server (host plays as a player)
- **Matchmaking / server browser** — standalone uses join codes via IP, Steam uses Steam lobby list
- **Account system / persistence** — no login, no cloud saves
- **Anti-cheat** — host authority is the trust model
- **Console platform support** — PC-only for MVP (Steam + Itch.io)
- **Web export** — ENet doesn't work in browsers
- **Mobile release** — deferred until after Steam launch
- **Steam Voice** — deferred to Phase 2 Steam integration; use godot-voip for all platforms initially
- **Proximity-based voice attenuation** — all voice is flat for MVP
- **Client-side prediction / reconciliation** — current architecture runs all players at full authority for movement
- **Host migration** — if host disconnects, the game ends (reserved for post-MVP)

---

## Further Notes

### Migration Order

The work should proceed in vertical slices, each independently testable:

| Slice | Description | Files Changed | Testable |
|---|---|---|---|
| 1 | Transport + Lobby | `game_manager.gd`, `lobby.gd`, new NetworkManager autoload | Can host + join + see player list |
| 2 | RPC + Authority | `danger_manager.gd`, `round_manager.gd`, `quota_manager.gd`, `fishing_mechanic.gd`, `player.gd` | Can play a full multiplayer session |
| 3 | Spawn + Property Sync | `spawn_manager.gd`, `player.tscn` (replace PropertySynchronizers) | Players spawn and sync position/state |
| 4 | Scene Loading | `game_manager.gd` (change_scene path) | Host triggers scene transitions |
| 5 | Voice | Add godot-voip, integrate with VoiceChatManager | Players can hear each other |
| 6 | Cleanup | Remove GD-Sync addon, project.godot config | Final step |

### Non-Steam Limitations

For standalone builds (Itch.io, direct download):
- Players must share the host's public IP address via external means (Discord, chat)
- UPnP works on ~70% of home routers; the remaining 30% cannot host without port forwarding or a VPN workaround (Hamachi, ZeroTier)
- LAN play works automatically with no configuration
- These limitations are accepted for the MVP on non-Steam platforms

### Godot-Voip Addon Integration

The godot-voip addon (`VoiceOrchestrator` node) automatically detects peer connections/disconnections and manages individual voice instances. Integration consists of:
1. Enable audio input in Project Settings
2. Enable the plugin in Project Settings -> Plugins
3. Add a `VoiceOrchestrator` node to the game scene
4. Set `recording = true` to begin capturing and transmitting mic audio
5. The existing `VoiceChatManager` continues to detect yelling from local mic amplitude — it reads from the same mic data independently

### Steam Integration (Phase 2)

Steam integration adds GodotSteam as a dependency but does not change any game networking code:
- Steam lobby replaces the IP-based join flow
- Steam lobby data carries the host's ENet connection info
- Steam SDR relay provides NAT traversal
- Steam display name replaces the generated "Player_X" name
- Gameplay networking (ENet, RPCs, spawner, synchronizer) is unchanged

The Steam check is a simple `Steam.is_steam_running()` at startup — no separate build configuration needed.
