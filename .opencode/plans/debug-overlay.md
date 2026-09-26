# Debug Overlay Integration & Enforcement Plan
**Status:** CLOSED - implemented (Issue #226)

## Overview
The `DebugOverlay` autoload (`autoloads/debug_overlay.gd`) provides an in-game F3-toggled debug panel for inspecting and mutating live state across core game managers. To prevent new managers from silently skipping debug monitoring, all system managers must adhere to a strict three-method debug contract and register themselves upon initialization.

## The Three-Method Contract

Every manager under `systems/<name>/<name>_manager.gd` must implement:

| Method | Return Type / Signature | Description |
|---|---|---|
| `get_debug_state()` | `Dictionary` | Returns key-value pairs of current live state. Polled each frame; changes auto-logged to debug history. |
| `get_debug_actions()` | `Array[Dictionary]` | Returns available debug actions as `{"id": "...", "label": "..."}` dicts (max 9 rendered). |
| `debug_action(action_id: String)` | `void` | Executes the requested action. Must be server-gated (`if multiplayer.has_multiplayer_peer() and not multiplayer.is_server(): return`). |

### Registration Snippet
In `_ready()`:
```gdscript
var dbg := get_node_or_null("/root/DebugOverlay")
if dbg:
	dbg.register_system(name, self)
```

## Covered Systems (The Intentional 7)
The debug overlay enforcement test (`tests/unit/test_debug_overlay_coverage.gd`) explicitly asserts contract compliance for the 7 core system managers:
1. `res://systems/round/round_manager.gd`
2. `res://systems/danger/danger_manager.gd`
3. `res://systems/danger/seagull_manager.gd`
4. `res://systems/rocks/rock_manager.gd`
5. `res://systems/zones/zone_manager.gd`
6. `res://systems/quota/quota_manager.gd`
7. `res://systems/quota/coin_manager.gd`

### Excluded Entities
Auxiliary gameplay entities, components, and interactables (such as `shark_bait`, `fireplace`, `shop_hut`, `health_component`) are intentionally excluded from the mandatory debug overlay manager contract as they are not top-level simulation system managers.

## Enforcement
`tests/unit/test_debug_overlay_coverage.gd` inspects each covered manager script via `get_script_method_list()` and safe instantiation to assert:
- Presence of all three required methods (`get_debug_state`, `get_debug_actions`, `debug_action`).
- Correct return type shapes (`Dictionary` for state, `Array[Dictionary]` with `id` and `label` for actions).
