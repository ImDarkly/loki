# Plan -- Issue #224: SeagullManager debug contract

**Branch:** `feature/224-seagullmanager-debug-contract` (pre-existing from prior planner run; `master` at `d728289`, `origin/master` in sync -- `git fetch origin` confirms fast-forward)
**Issue:** https://github.com/ImDarkly/loki/issues/224 -- "SeagullManager debug contract"
**Status:** Planning only -- no implementation writes beyond this docs file and prior branch creation.
**Skills loaded:** `godot-testing` (GUT patterns, autofree/before_each), `multiplayer-basics` (server-gated RPC, authority/any_peer), `hud-system` (reference, not directly touched)

---

## 1. Issue Summary (verbatim from `gh issue view 224`)

> ## What to build
> Seagull system becomes visible and controllable: state, roam/spawn/return timers, position; actions like force spawn, skip roam -> approach, force retreat.
>
> ## Acceptance criteria
> - [ ] `SeagullManager` calls `DebugOverlay.register_system` unconditionally in `_ready()`
> - [ ] Implements three-method contract, server-gated mutations
> - [ ] Honors `fishing_active` and quota-gating already in manager
>
> ## Blocked by
> - Cheat action pipeline (any-peer -> server)
>
> ## Notes
> Recommended after DangerManager per spec rollout order.

Comments: none. Labels: `feature`. State: `OPEN`.

Blocked-by #221 (Cheat action pipeline) is **now merged** at `69f0134` (#229) -- `DebugOverlay._debug_action_rpc` any_peer->server and focus/1-9 dispatch are live. DangerManager debug contract (#223) merged at `d728289` (#231) is the direct reference implementation.

---

## 2. Verified Ground Truth (files actually viewed this session)

All paths below were `read`/`glob`/`bash ls` in this session -- no assumptions:

- `systems/danger/seagull_manager.gd` (430 lines, viewed) -- `extends Node3D`, `enum State { INACTIVE, ROAMING, APPROACHING, ATTACKING, RETREATING, WAITING }`, `@export flight_altitude/roaming_altitude/roam_radius/roam_duration_min-max/flight_speed/repel_radius/arrival_range/theft_amount/spawn_interval_min-max/return_interval_min-max`, `var current_state`, `var seagull_node: MeshInstance3D`, `var spawn_position`, `_roam_center/_roam_angle/_storage_box/_sync_tick/_round_manager/_last_fishing_active`, `@onready spawn_timer/return_timer/roam_timer`, `_ready()` currently gated `if OS.is_debug_build(): dbg.register_system(name,self)`, then resolves `_storage_box`/`_round_manager`, non-server `set_physics_process(false)` + stop timers, hooks `one_shot` + `timeout` connects, `spawn_timer.start(randf_range(...))`. Has `_get_quota_manager()`, `_can_spawn()` (checks `shared_quota>0`), `_on_roam_timer_timeout()` (ROAMING->APPROACHING), `_on_spawn_timer_timeout()` (checks fishing_active + _can_spawn -> WAITING+return_timer, else _spawn_seagull+ROAMING+roam_timer), `_on_return_timer_timeout()` similarly, `_spawn_seagull()` (roam_center from StorageBox or MAP_CENTER, MeshInstance3D via SurfaceTool), `_physics_process` (fishing_active pause/resume, ROAMING/APPROACHING/RETREATING), `repel(any_peer,unreliable,call_remote)` server-gated, `_sync_state_to_clients` / `_apply_synced_state(authority,reliable,call_local)`, `reset_for_restart()`, `get_debug_state()->Dictionary` currently `{state, seagull_visible, spawn}` only.
- `systems/danger/seagull_manager.tscn` (12 lines, viewed) -- `SeagullManager:Node3D` + `SpawnTimer:Timer` + `ReturnTimer:Timer` + `RoamTimer:Timer`.
- `systems/danger/danger_manager.gd` (517 lines, viewed) -- **reference implementation** for this issue. `_ready()` now unconditional `var dbg=get_node_or_null("/root/DebugOverlay"); if dbg: dbg.register_system(name,self)` (no OS.is_debug_build gate). `get_debug_state()` returns `{state, targeting_bait, shark_visible, spawn, spawn_timer_left, return_timer_left, shark_pos}` with `max(0,int(ceil(timer.time_left)))`. `get_debug_actions()->Array[Dictionary]` 4 actions `force_spawn/force_retreat/force_attack/reset_inactive` with labels. `debug_action(action_id)` server-gated `if multiplayer.has_multiplayer_peer() and not multiplayer.is_server(): return` then match -> `_debug_force_spawn/_debug_force_retreat/_debug_force_attack/_debug_reset_inactive`. Each helper respects existing gating (`_get_nearest_player()==null` early return, stop timers, _spawn, set state, _sync). Not synced bait state intentionally.
- `systems/round/round_manager.gd` (170 lines, viewed) -- also unconditional `register_system`, `get_debug_state` `{round_active, round_success, fishing_active, time_left:int}`, `get_debug_actions` 5 actions, `debug_action` server-gated.
- `systems/quota/quota_manager.gd` (58 lines, viewed) -- still gated `if OS.is_debug_build()` (not yet migrated), `get_debug_state` `{shared_quota}`, `get_debug_actions` `{+10 Quota, Clear Quota}`, `debug_action` server-gated.
- `autoloads/debug_overlay.gd` (315 lines, viewed) -- CanvasLayer layer 150, OS.is_debug_build gated _init/_ready/_process/_input/register_system, visible false start, F3 InputMap toggle_debug_overlay, PanelContainer 20,20 420x320 StyleBoxFlat 0,0,0,0.7 mouse_filter IGNORE, VBox: _title_label, _systems_label, _live_label, _actions_label, HSeparator, ScrollContainer 80px + _history_label, _content_label=_live_label. _systems:Dictionary, _prev_states, _history:Array[String] HISTORY_MAX=200, _focused_index, _test_force_client/_test_rpc_called_count. _process: _scan_tree_for_debug, dead prune, diff get_debug_state shallow != with duplicate(true), capped 200, render sorted keys focus, live lines `k: str(v)`, actions truncated 9, _input: Tab/Down/Up focus, 1-9 dispatch via `has_method("get_debug_actions")` then `has_method("debug_action")` -> local if is_server else `_debug_action_rpc.rpc(focused_name,aid)` (any_peer reliable call_remote server-gated).
- `tests/unit/test_seagull_manager.gd` (346 lines, viewed) -- GUT, before_each parent StorageBox + scene instantiate + await + stop timers, 18 tests covering initial INACTIVE, spawn mesh, perimeter altitude, approaching advance, arrival attack->WAITING, repel in/out range, retreating vanish/boundary, return_timer, theft penalty, fishing paused/resumed, reset_for_restart, player throw repel, round restart reset.
- `tests/unit/test_danger_manager.gd` (395 lines, viewed) -- 30 tests including get_debug_state keys/types, get_debug_actions 4 ids/labels, debug_actions execution, client noop via ENetMultiplayerPeer, bait_not_synced.
- `tests/unit/test_round_manager.gd` (165 lines) -- debug_state keys, actions 5, execution, resume ignored when timer stopped.
- `tests/unit/test_debug_overlay.gd` (262 lines) + `test_debug_overlay_actions.gd` (217 lines) + `test_debug_overlay_history.gd` (viewed via glob) -- F3 toggle without mouse_mode, pruning, focus cycling, 1-9 dispatch host vs client via _test_force_client, missing method not crash.
- `scenes/dev/dev_seagull_flow.tscn` + `dev_seagull_flow.gd` (97 lines, viewed) -- instantiates SeagullManager directly, shortens timers in dev script only (spawn 2s, return 5s), HUD Label State/Roam/Spawn/Return/Quota/Pos, F5 full cycle, F6 skip roam->_on_roam_timer_timeout, G +5 fish, R reset, H time_scale. No DebugOverlay interaction needed.
- `scenes/dev/README.md` (viewed via prior plan), `.gutconfig.json` dirs ["res://tests/unit"] prefix test_ suffix .gd, `project.godot` autoload order game_manager -> NetworkManager -> DebugOverlay (after HLobbies per test).
- `autoloads/game_manager.gd` (157 lines), `addons/` confirmed gitignored (exists locally but per AGENTS.md must not assume).
- Listings: `systems/` 8 subdirs, `autoloads/` 3 files, `tests/unit/` 32 files, `scenes/dev/` 3 flows.

---

## 3. Branch

```
feature/224-seagullmanager-debug-contract
```

- Created on prior planner invocation from `master` at `d728289` (also `origin/master`/`origin/HEAD`). `git branch --show-current` confirms `feature/224-seagullmanager-debug-contract`.
- `git fetch origin` run this session -- already fast-forward, `master` == `origin/master` == `d728289`.
- Working tree status: untracked `.opencode/agents/`, `pr_body.md`, `test_hello.gd/.uid`, `test_output.log`, `triage_comment.md` (pre-existing planner debris, not staged). No modified tracked files. Per AGENTS.md Startup Workflow dirty-tree check: these are unrelated untracked files; planner does **not** branch over them, notes them and proceeds to plan revision on existing branch per retry rule.

If orchestrator intended a fresh branch, desired sequence would have been `git checkout master; git fetch origin; git checkout -b feature/224-seagullmanager-debug-contract` -- but branch already exists with correct naming convention (`feature/` + issue number + slug).

---

## 4. Assumptions

1. `DebugOverlay.register_system` must be **unconditional** (no `OS.is_debug_build()` guard) to satisfy acceptance `[ ] SeagullManager calls DebugOverlay.register_system unconditionally in _ready()` -- mirroring `danger_manager.gd:42-44` and `round_manager.gd:18-20` after #230/#231. Debug gating remains inside `DebugOverlay.register_system` itself (`if not OS.is_debug_build(): return`).
2. Three-method contract means exactly `get_debug_state()->Dictionary`, `get_debug_actions()->Array[Dictionary]` (`{id,label}`), `debug_action(action_id:String)->void` with server-gated mutations (`if multiplayer.has_multiplayer_peer() and not multiplayer.is_server(): return`).
3. Server-gated mutations follow `danger_manager.gd:471-472` / `quota_manager.gd:29-30`: check `has_multiplayer_peer() and not is_server()` at top of `debug_action` and each helper if they do state changes, not at `repel` level (repel already has its own guard).
4. Honors `fishing_active` and quota-gating already in manager -- debug actions must **not bypass** the quota/fishing gates that `_on_spawn_timer_timeout`/`_on_return_timer_timeout` enforce. Concretely: `force_spawn` should early-return if `!_can_spawn()` or `fishing_active==false` (or at least mirror spawn path that goes to WAITING+return_timer when quota empty, not forced spawn). Ambiguity noted below -- propose gated variant, fallback to unconditional for manual testing if user prefers.
5. State string uses `State.keys()[current_state]` (Pascal enum name) for human-readable history verbatim rendering, as in `danger_manager.gd:451` and `round_manager.gd:124`.
6. Timer fields are `int(ceil(time_left))` with `max(0, ...)` and `is_instance_valid(timer)` guard -- pattern from `danger_manager.gd:455-456`.
7. Position is stringified `Vector3` via `str()` for verbatim panel, e.g. `str(spawn_position)` and `str(seagull_node.position if valid else Vector3.ZERO)`.
8. No new `scenes/dev/dev_<system>_flow.tscn` needed -- one already exists and is not stale; this slice only adds debug contract to existing manager per Manual/Dev Testing convention ("when a new system manager is introduced...").
9. `addons/` is gitignored -- no addon path cited; GUT invocation is `C:\Godot\Godot_v4.6.2-stable_win64.exe --headless --path . -s addons/gut/gut_cmdln.gd`.
10. `DebugOverlay` auto-discovers via `_scan_tree_for_debug` but explicit `register_system` is still required for immediate visibility without waiting for scan; both coexist.

---

## 5. Ambiguities Requiring User Input Before Implementation

1. **Force spawn semantics vs quota/fishing gate:** Should `force_spawn` honor `fishing_active==false` and `_can_spawn()==false` (early return or go to WAITING + return_timer like normal spawn path) or force-spawn unconditionally for manual testing? DangerManager force_spawn checks `_get_nearest_player()==null` but not bait/quota; Seagull spec says "Honors fishing_active and quota-gating already in manager" -- suggests gated. Which is desired?
2. **Exact action set:** Spec lists `force spawn, skip roam -> approach, force retreat`. Danger has 4 actions (adds force_attack, reset_inactive). Propose Seagull 4 actions: `force_spawn` (spawn+ROAMING), `skip_roam` (ROAMING->APPROACHING via `_on_roam_timer_timeout`), `force_retreat` (any active->RETREATING), `reset_inactive` (->INACTIVE). Is `force_attack` (skip to theft) out of scope for seagull since attack is instantaneous? Confirm IDs/labels.
3. **Skip-roam label/ID:** `skip_roam` vs `force_approach` vs `skip_roam_approach` -- Danger uses no skip; dev_seagull_flow uses F6 `_on_roam_timer_timeout`. Propose `skip_roam` label "Skip Roam -> Approach" or simply "Skip Roam". Need canonical id.
4. **Debug state key set:** Minimal currently `{state, seagull_visible, spawn}`. Required: `state, seagull_visible, spawn, spawn_timer_left, return_timer_left, roam_timer_left, seagull_pos` plus maybe `roam_duration`? Spec says "state, roam/spawn/return timers, position" -- propose 7-8 keys: `state, seagull_visible, spawn, spawn_timer_left, return_timer_left, roam_timer_left, seagull_pos` (and optionally `fishing_active`, `quota_ok`). Confirm which extra keys to include; avoid leaking `fishing_active` duplication if RoundManager already shows it.
5. **Quota check includes _can_spawn path:** `_can_spawn()` checks `QuotaManager.shared_quota>0`. Should debug state expose `quota_ok` or `shared_quota` for visibility, or keep seagull-local only? Danger exposes `targeting_bait` but not bait fill; Seagull could expose `quota_ok` bool.
6. **Client noop test vs ENet peer creation:** Existing tests use `ENetMultiplayerPeer.create_client("127.0.0.1",1)` to fake client -- should replicate that or use `_test_force_client` pattern from DebugOverlay? Danger tests use ENet peer; propose same.

If no answer, default to gated `force_spawn` (respects fishing_active + quota), 4 actions `{force_spawn, skip_roam, force_retreat, reset_inactive}`, 7 debug_state keys `{state, seagull_visible, spawn, spawn_timer_left, return_timer_left, roam_timer_left, seagull_pos}`.

---

## 6. Structure (Project Conventions)

- `systems/danger/seagull_manager.gd` -- only domain file touched (Node3D, snake_case, `_` prefix private, `@export` unchanged, typed signals not needed).
- `systems/danger/danger_manager.gd` -- reference only, not touched.
- `autoloads/debug_overlay.gd` -- not touched (already supports three-method contract via `_debug_action_rpc` and history polling).
- `tests/unit/test_seagull_manager.gd` -- extend with debug contract tests. No new test file strictly required but `test_danger_manager.gd` pattern colocates contract tests there; extend existing file.
- `scenes/dev/dev_seagull_flow.gd/.tscn` -- not touched; already shortens timers in dev script per convention.
- `docs/godot-prompter/plans/plan-224-*.md` -- this plan file.

---

## 7. Code Style & Multiplayer

- snake_case vars/funcs/signals, PascalCase class_name/autoload, `_` prefix private (`_debug_force_spawn`), `@export` vars unchanged, `const` if needed, no comments unless non-obvious intent.
- Server-gated: `if multiplayer.has_multiplayer_peer() and not multiplayer.is_server(): return` at top of `debug_action` and each `_debug_*` helper that mutates `current_state`/spawns/timers -- same as `danger_manager.gd:470-472` and `round_manager.gd:143-144`.
- RPC: no new RPCs needed; reuse existing `_sync_state_to_clients` / `_apply_synced_state` (`@rpc("authority", "call_local", "reliable")`) for mutations; cheat dispatch arrives via `DebugOverlay._debug_action_rpc` (`@rpc("any_peer", "reliable", "call_remote")`) already server-gated.
- `is_instance_valid(seagull_node)` and `is_instance_valid(timer)` guards before `time_left` reads, per `danger_manager` pattern.
- `State.keys()[current_state]` with bounds fallback `if current_state < State.size() else str(current_state)`.

---

## 8. Detailed Implementation Steps

### Step 1 -- Make `register_system` unconditional in `_ready()`

**File:** `systems/danger/seagull_manager.gd` (verified, line 33-37)

Current:
```gdscript
func _ready() -> void:
    if OS.is_debug_build():
        var dbg = get_node_or_null("/root/DebugOverlay")
        if dbg:
            dbg.register_system(name, self)
```

Change to (pattern from `danger_manager.gd:41-44`, `round_manager.gd:17-20`):
```gdscript
func _ready() -> void:
    var dbg = get_node_or_null("/root/DebugOverlay")
    if dbg:
        dbg.register_system(name, self)
```

Keep the rest of `_ready()` exactly: `_storage_box`/`_round_manager` resolution, non-server `set_physics_process(false)` + stop timers, `one_shot` + connect, `spawn_timer.start(...)`. No OS gate, no `visible` toggle. Gating stays inside `DebugOverlay.register_system`.

*Pattern:* server-gated RPC pattern not involved; overlay pruning pattern from `debug_overlay.gd`.

*Out of scope:* do not migrate `quota_manager.gd` gating in this slice.

**Verify:** `test_seagull_manager` still passes; DebugOverlay pruning test `test_debug_overlay.gd` should show SeagullManager auto-registered without waiting for `_scan_tree_for_debug` (first frame).

### Step 2 -- Expand `get_debug_state()` to full visible state

**File:** `systems/danger/seagull_manager.gd` (line 425-430)

Current returns 3 keys `{state, seagull_visible, spawn}`. Replace with 7 keys mirroring `danger_manager.gd:449-458`:

```gdscript
func get_debug_state() -> Dictionary:
    return {
        "state": State.keys()[current_state] if current_state < State.size() else str(current_state),
        "seagull_visible": is_instance_valid(seagull_node) and seagull_node.visible,
        "spawn": str(spawn_position),
        "spawn_timer_left": max(0, int(ceil(spawn_timer.time_left))) if is_instance_valid(spawn_timer) else 0,
        "return_timer_left": max(0, int(ceil(return_timer.time_left))) if is_instance_valid(return_timer) else 0,
        "roam_timer_left": max(0, int(ceil(roam_timer.time_left))) if is_instance_valid(roam_timer) else 0,
        "seagull_pos": str(seagull_node.position) if is_instance_valid(seagull_node) else str(Vector3.ZERO)
    }
```

Optional 8th key if user confirms: `"fishing_active": _round_manager.fishing_active if _round_manager and "fishing_active" in _round_manager else true` and/or `"quota_ok": _can_spawn()` -- but keep minimal 7 to satisfy "state, roam/spawn/return timers, position" verbatim.

*Pattern:* `danger_manager.get_debug_state` + `round_manager.get_debug_state` verbatim rendering + `HistoryPolling` shallow diff.

**Verify:** new keys appear in F3 overlay live panel for focused SeagullManager; history auto-logs on spawn_timer expiry (`spawn_timer_left` 2->0) and state ROAMING->APPROACHING via roam_timer.

### Step 3 -- Implement `get_debug_actions()` -- 3-4 controlled actions

**File:** `systems/danger/seagull_manager.gd` (new method after `get_debug_state`)

Propose 4 actions to mirror DangerManager while covering spec (force spawn, skip roam->approach, force retreat):

```gdscript
func get_debug_actions() -> Array[Dictionary]:
    return [
        {"id": "force_spawn", "label": "Force Spawn"},
        {"id": "skip_roam", "label": "Skip Roam -> Approach"},
        {"id": "force_retreat", "label": "Force Retreat"},
        {"id": "reset_inactive", "label": "Reset Inactive"}
    ]
```

If strict 3 required, drop `reset_inactive` (but Danger and Round both have it; keep for consistency). IDs must be stable for 1-9 dispatch; labels truncated to 9 entries by overlay.

*Pattern:* `danger_manager.get_debug_actions` (4), `round_manager.get_debug_actions` (5), `quota_manager.get_debug_actions` (2).

**Verify:** Focus SeagullManager in overlay (Tab), actions render as `1: Force Spawn` etc.; truncation not triggered (<9).

### Step 4 -- Implement `debug_action(action_id:String)` server-gated dispatcher + helpers

**File:** `systems/danger/seagull_manager.gd` (new)

```gdscript
func debug_action(action_id: String) -> void:
    if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
        return
    match action_id:
        "force_spawn":
            _debug_force_spawn()
        "skip_roam":
            _debug_skip_roam()
        "force_retreat":
            _debug_force_retreat()
        "reset_inactive":
            _debug_reset_inactive()
```

Helpers (server-gated again, following `danger_manager.gd:484-517`):

- `_debug_force_spawn()`:
  ```gdscript
  func _debug_force_spawn() -> void:
      if _round_manager and "fishing_active" in _round_manager and not _round_manager.fishing_active:
          return  # honor fishing_active
      if not _can_spawn():
          return  # honor quota-gating -- alternatively go to WAITING+return_timer like _on_spawn_timer_timeout does when quota empty
      spawn_timer.stop()
      return_timer.stop()
      roam_timer.stop()
      _spawn_seagull()
      current_state = State.ROAMING
      roam_timer.start(randf_range(roam_duration_min, roam_duration_max))
      _sync_state_to_clients()
  ```
  Note: if quota empty and spec instead wants visible WAITING, change to:
  ```
  if not _can_spawn():
      if current_state != State.WAITING: current_state = State.WAITING
      return_timer.start(randf_range(return_interval_min, return_interval_max))
      _sync_state_to_clients(); return
  ```
  Pick gated variant per Assumption 4; ask user if unconditional preferred.

- `_debug_skip_roam()`:
  ```gdscript
  func _debug_skip_roam() -> void:
      if current_state != State.ROAMING:
          return
      _on_roam_timer_timeout()  # ROAMING->APPROACHING
  ```
  If spec wants skip from any pre-approach, alternative: if INACTIVE/WAITING then force_spawn then skip, but keep minimal: only from ROAMING per dev_seagull_flow.gd:92.

- `_debug_force_retreat()`:
  ```gdscript
  func _debug_force_retreat() -> void:
      if current_state == State.INACTIVE or current_state == State.WAITING:
          if _round_manager and "fishing_active" in _round_manager and not _round_manager.fishing_active:
              return
          if not _can_spawn():
              return
          spawn_timer.stop()
          return_timer.stop()
          _spawn_seagull()
          current_state = State.APPROACHING  # or ROAMING then retreat? Danger spawns then retreats; Seagull retreat expects visible node
      _trigger_retreat()
  ```
  Reuse existing `_trigger_retreat()` which sets State.RETREATING + sync.

- `_debug_reset_inactive()`:
  ```gdscript
  func _debug_reset_inactive() -> void:
      reset_for_restart()
  ```
  Reuses existing `reset_for_restart()` which already server-gates, hides node, INACTIVE, restarts spawn_timer.

All mutations go through `_sync_state_to_clients()` already; no new RPC.

*Pattern:* `danger_manager.debug_action` + `_debug_force_*` helpers with `if multiplayer.has_multiplayer_peer() and not multiplayer.is_server(): return` early exit; `round_manager.debug_action` similar; `DebugOverlay._debug_action_rpc` dispatches on client.

**Verify:** Host: 1 triggers Force Spawn -> state ROAMING, visible true, roam_timer running; 2 while ROAMING -> APPROACHING; 3 -> RETREATING; 4 -> INACTIVE. Client (ENet peer client): same 1-9 presses no-op locally (debug_action early return), instead RPC branch increments `_test_rpc_called_count` (or would RPC to server in real MP).

### Step 5 -- No dev scene changes (confirmed)

**Files:** `scenes/dev/dev_seagull_flow.tscn` / `dev_seagull_flow.gd` -- **no changes**. Already implements isolated flow with shortened timers, HUD, F5/F6 shortcuts. New cheat pipeline replaces manual F5/F6 for debug overlay users, but keep F5/F6 as dev-scene-only shortcuts per convention (shorten timers in dev script, not in manager @export defaults).

If new manager introduced would need `dev_<system>_flow`, not here.

**Verify:** `dev_seagull_flow.tscn` still runs standalone without NetworkManager/lobby, F3 overlay now shows SeagullManager with live timers.

---

## 9. Test Plan (GUT, `tests/unit/test_seagull_manager.gd` extension)

Config: `.gutconfig.json` dirs ["res://tests/unit"], prefix test_, suffix .gd, `extends GutTest`, `before_each()` autofree+add_child+await, `autofree()`.

Add to `test_seagull_manager.gd` (following `test_danger_manager.gd:330-395`):

| Test | Behavior verified | Pattern |
|------|-------------------|---------|
| `test_get_debug_state_returns_expected_keys` | keys `state`, `seagull_visible`, `spawn`, `spawn_timer_left`, `return_timer_left`, `roam_timer_left`, `seagull_pos` present; timer_left TYPE_INT | `test_danger_manager.gd:test_get_debug_state_returns_expected_keys` |
| `test_get_debug_state_types_and_bounds` | `state` is String from `State.keys`, timer_left `max(0, ceil)` non-negative | danger/round |
| `test_get_debug_actions_returns_three_or_four` | size 3 or 4, ids contain `force_spawn`, `skip_roam`/`force_approach`, `force_retreat` (and `reset_inactive` if kept) | `test_danger_manager.gd:test_get_debug_actions_returns_four_actions` |
| `test_get_debug_actions_labels` | labels match spec "Force Spawn", "Skip Roam -> Approach", "Force Retreat" | danger labels test |
| `test_debug_actions_execution` | `debug_action("force_spawn")` -> ROAMING + visible true; `skip_roam` while ROAMING -> APPROACHING; `force_retreat` -> RETREATING; `reset_inactive` -> INACTIVE (host, no peer) | `test_danger_manager.gd:test_debug_actions_execution` |
| `test_debug_action_honors_fishing_active_gate` | set RoundManager.fishing_active=false, `force_spawn` stays INACTIVE/WAITING (or goes WAITING per gate) | seagull-specific acceptance "Honors fishing_active" |
| `test_debug_action_honors_quota_gate` | set QuotaManager.shared_quota=0, `force_spawn` no spawn or ->WAITING + return_timer started | "Honors quota-gating" |
| `test_debug_action_client_noop` | ENetMultiplayerPeer create_client, `debug_action("force_spawn")` no state change | `test_danger_manager.gd:test_debug_action_client_noop` |
| `test_register_system_unconditional` | instantiate SeagullManager without OS.is_debug_build guard, check `DebugOverlay._systems.has("SeagullManager")` after `_ready` (or mock DebugOverlay register) | round/danger after migration |

Reuse `test_debug_overlay.gd` client RPC test: overlay `_test_force_client=true` triggers RPC branch not local.

**Verify command:** `C:\Godot\Godot_v4.6.2-stable_win64.exe --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gprefix=test_ -gsuffix=.gd` -- expect all 18 existing + 8-9 new green, no failures in `test_debug_overlay*`, `test_danger_manager`, `test_round_manager`.

---

## 10. Explicitly Out of Scope (scope-creep guard)

- New `MultiplayerSynchronizer` or `_sync_state_to_clients` changes -- reuse existing.
- `QuotaManager`/`CoinManager` unconditional migration -- separate slice (quota still gated `OS.is_debug_build`).
- Tab/arrow focus cycling, 1-9 dispatch, `_debug_action_rpc` -- already in #221/#229, not touched.
- 1-9 global mapping or Clickable Buttons -- overlay already does 1-9, no Button nodes (`test_no_button_nodes` pattern).
- History polling/ring buffer/F3 layout -- #220 shipped, not touched.
- New `scenes/dev/dev_seagull_flow.tscn` -- already exists, no new dev scene per AGENTS.md "when new manager introduced" (not this slice).
- Changes to `flight_altitude`, `roaming_altitude`, `roam_radius`, `theft_amount`, `arrival_range` exports or `repel()` logic.
- Disk persistence (ConfigFile/JSON), theming, `addons/` changes.
- Force-spawning when quota empty if spec says to honor gate -- do not add unconditional bypass unless user clarifies.

---

## 11. Verification Checklist

1. Step1 unconditional -> `test_register_system_unconditional` passes; manual: run `dev_seagull_flow.tscn` headless, F3 shows SeagullManager immediately (no need to wait for scan).
2. Step2 state -> F3 live panel shows 7 keys updating verbatim; history logs `state ROAMING -> APPROACHING` when roam_timer expires.
3. Step3 actions -> F3 actions label shows `1: Force Spawn` etc.; `_input` 1-9 dispatches to `debug_action`.
4. Step4 dispatcher host -> 1-4 mutate state + timers + sync; client peer no-ops (or RPCs via overlay).
5. Step4 gates -> `fishing_active=false` blocks force_spawn; `shared_quota=0` blocks/redirects to WAITING per `_can_spawn`.
6. Full GUT headless green: all `test_*.gd` pass.
7. Manual spot: `dev_seagull_flow.tscn` F5 still works, F6 skip roam still works, overlay 1=Force Spawn etc., mouse_mode unchanged on F3.

---

## 12. Risks

- Duplicate snapshot aliasing: `get_debug_state` must return new Dictionary each call, overlay does `duplicate(true)` -- already safe.
- Enum string vs int: use `State.keys()[current_state]` for history readability (like Danger/Round), not int.
- Timer `time_left` on stopped Timer returns 0 -- `max(0,ceil)` guards negative, `is_instance_valid` guards freed timers in tests.
- `ENetMultiplayerPeer.create_client` in tests leaves peer open -- must `multiplayer.multiplayer_peer=null` in cleanup to avoid cross-test pollution (pattern in `test_danger_manager.gd:382-388`).
- `addons/` gitignore: do not cite `addons/gut` path as guaranteed remote, but local exists per `test_output.log`.

---

## Appendix: File Touch Summary (grounded)

| File | Touch | Why |
|------|-------|-----|
| `systems/danger/seagull_manager.gd` | **Modify** | unconditional register, expand get_debug_state, add get_debug_actions + debug_action + helpers |
| `tests/unit/test_seagull_manager.gd` | **Extend** | 8-9 new GUT tests for contract + gates |
| `autoloads/debug_overlay.gd` | **No touch** | already supports contract |
| `systems/danger/seagull_manager.tscn` | **No touch** | timers already there |
| `scenes/dev/dev_seagull_flow.*` | **No touch** | already per convention |
| `docs/godot-prompter/plans/plan-224-seagull-debug-contract.md` | **Create** | this plan |

End of plan -- awaiting user clarification on Ambiguities (esp. 1-4) before coding, else proceed with gated force_spawn, 4 actions, 7 keys defaults on `feature/224-seagullmanager-debug-contract`.

