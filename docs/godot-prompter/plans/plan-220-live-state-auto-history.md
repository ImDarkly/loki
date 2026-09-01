# Plan — Issue #220: Live state and auto-history engine

**Branch:** `feature/220-live-state-auto-history` (created from `master` at `3761b0f`, fast-forwarded via `origin/master`)
**Issue:** https://github.com/ImDarkly/loki/issues/220 — "Live state and auto-history engine"
**Status:** Planning only — no implementation writes beyond this docs file and branch creation.
**Skills loaded:** `godot-testing` (GUT patterns), `hud-system` (CanvasLayer HUD architecture), `godot-ui` (Control/Label/ScrollContainer layout)

---

## 1. Issue Summary (verbatim)

From `gh issue view 220`:

> Once a system provides `get_debug_state() -> Dictionary`, the overlay polls it each frame, renders its key/value pairs verbatim, and auto-generates a timestamped history line whenever any field changes (e.g. "DangerManager: state WAITING -> APPROACHING"). Ring buffer ~200 entries, no manual `log_event()` sites.

Acceptance:

- [ ] Field-level diff of `get_debug_state()` produces one log line per changed field
- [ ] History is timestamped and capped at ~200 entries
- [ ] Panel renders live key/values for the focused system

Blocked by #219 (DebugOverlay scaffold — **now merged** at `3761b0f`).

Related forward issue: #221 Cheat action pipeline (Tab/arrow focus cycling, 1-9 RPC).

---

## 2. Verified Ground Truth (files actually viewed this session)

All paths below were `read`/`cat`/`ls` in this session — no assumptions:

- `autoloads/debug_overlay.gd` (105 lines, viewed) — CanvasLayer, OS.is_debug_build() gated, layer=150, _systems Dictionary, per-frame is_instance_valid pruning, F3 InputMap toggle_debug_overlay, PanelContainer 20,20,420,200 StyleBoxFlat 0,0,0,0.7, VBoxContainer -> _title_label + _content_label. _process currently renders get_debug_status/get_state fallback — must replace with get_debug_state polling.
- `project.godot` (61 lines, viewed) — [autoload] order game_manager, NetworkManager, EOSGRuntime, HPlatform, HAuth, HLobbies, DebugOverlay (after HLobbies). [input] toggle_debug_overlay on KEY_F3 (4194334). editor_plugins gut.
- `tests/unit/test_debug_overlay.gd` (103 lines, viewed) — GUT: before_each load+autofree+add_child+await, 7 tests covering register, repeated/null, pruning via _process(0.016), InputMap F3, F3 visibility without mouse_mode, autoload order, debug gating.
- `systems/danger/danger_manager.gd` (441 lines, viewed) — State enum INACTIVE..WAITING, current_state, bait_priority_range, repel, reset_for_restart, sync. No get_debug_state yet.
- `systems/danger/seagull_manager.gd` (417 lines, viewed) — State INACTIVE..WAITING, current_state, SpawnTimer/ReturnTimer/RoamTimer.
- `systems/shark_bait/shark_bait_manager.gd` (171 lines, viewed) — SharkBaitManager, is_placed, placed_position, bait_fill_count, fill_cost.
- `systems/quota/coin_manager.gd` (133 lines, viewed) — CoinManager, coins, fireplace_owned, shark_bait_owned.
- `systems/quota/quota_manager.gd` (viewed) — shared_quota, report_catch, apply_penalty, _sync_quota.
- `systems/round/round_manager.gd` (116 lines, viewed) — round_active, fishing_active, restart_round, _apply_restart.
- `autoloads/game_manager.gd` (157 lines, viewed) — players Array, Player_<id> naming.
- `.gutconfig.json` (viewed) — dirs ["res://tests/unit"], prefix test_, suffix .gd.
- `scenes/dev/dev_seagull_flow.gd` (97 lines, viewed) — reference dev scene: instantiates manager directly, shortens timers in dev script only, HUD Label, F5/F6/G/R/H shortcuts.
- `scenes/dev/README.md` (82 lines, viewed) — Manual/Dev Testing convention.
- Listings verified: systems/ (10 subdirs), autoloads/ (3), tests/unit/ (29 files), scenes/dev/ (dev_seagull_flow, dev_shark_bait_flow, dev_shop_flow).
- addons/ is gitignored per AGENTS.md — not assumed.

---

## 3. Branch

```
feature/220-live-state-auto-history
```

Derived from master (3761b0f) after git checkout master; git fetch origin; git merge --ff-only origin/master. Working tree clean (only untracked .opencode/ ignored). git branch --show-current confirms feature/220-live-state-auto-history.

---

## 4. Assumptions

1. Debug-only gating stays. No behavior change for release builds.
2. get_debug_state() is opt-in duck-typed. Checked via has_method. Non-Dictionary treated as empty, no error.
3. History is local-only, not synced. No RPC, no MultiplayerSynchronizer.
4. "Focused system" means single-system live panel. #221 adds Tab/arrow cycling; for #220 render one focused entry (default index 0) or note divergence if intent was stacked all-systems — see Ambiguities.
5. Ring buffer exactly 200, drop oldest on overflow. const HISTORY_MAX = 200.
6. Timestamp format HH:MM:SS via Time.get_time_string_from_system() or ticks via Time.get_ticks_msec(), injected via _get_timestamp() for test determinism. Suggested line: "[HH:MM:SS] System: key old -> new".
7. Field-level diff produces one line per changed field per frame. New keys and removed keys also produce a line. Shallow Dictionary diff with != variant comparison.
8. Polling every _process frame.
9. Verbatim rendering via str(value).
10. No manual log_event seam — auto-diff only.

---

## 5. Ambiguities Requiring User Input

1. Focused vs all-systems rendering: Should #220 show only focused system's keys (with minimal _focused_index=0) or stacked all systems and #221 narrows to focused+highlight?
2. Timestamp source/format: wall-clock [HH:MM:SS] vs tick [12345ms]?
3. History ordering: newest at top or bottom? With ScrollContainer, bottom-append common.
4. History line format for non-state keys and new/removed keys: "System: key added (value)" / "System: key removed"? Generic "System: key old -> new" OK?
5. Pruning vs history: When node pruned and re-registered, clear _prev_states[sys_name] to avoid storm?
6. Empty initial state: First appearance seeds silently (no lines) or emits added lines for every key? Propose silent seeding.

---

## 6. Structure (Project Conventions)

- autoloads/ — DebugOverlay stays CanvasLayer singleton after HLobbies. Only file changed there is debug_overlay.gd.
- entities/ — untouched.
- systems/ — optional additive get_debug_state() -> Dictionary on 1-2 exemplars (danger_manager.gd, quota_manager.gd, coin_manager.gd) for demonstrability. Core contract is duck-typed; tests use mocks.
- tests/unit/ — GUT tests, prefix test_, extends GutTest. Extend test_debug_overlay.gd or add test_debug_overlay_history.gd (preferred).
- scenes/dev/ — No new dev scene required per AGENTS.md (no new systems/<name>/<name>_manager.gd introduced). Manual verification via existing dev_seagull_flow.tscn or dev_shark_bait_flow.tscn + F3.

---

## 7. Code Style & Multiplayer

- snake_case vars/funcs, PascalCase class_name, _ prefix private (_history, _prev_states, _focused_index, _history_label, _live_label), const HISTORY_MAX, signals typed if added.
- No comments unless non-obvious.
- Server-gated if not multiplayer.is_server(): return — NOT used (overlay is client-local).
- RPC authority/any_peer — NOT used in this slice (introduced in #221 as _debug_action_rpc).
- is_instance_valid pruning each _process — retain exactly.

---

## 8. Detailed Implementation Steps

### Step 1 — Extend DebugOverlay state + layout

File: autoloads/debug_overlay.gd (verified, 105 lines)

- Add: const HISTORY_MAX:int = 200, var _history:Array[String]=[], var _prev_states:Dictionary={}, var _focused_index:int=0, var _live_label:Label, var _history_label:Label, var _scroll:ScrollContainer, var _focused_name:String=""
- Keep OS.is_debug_build() gating in _init/_ready/_process/_input/register_system, visible=false start, set_process(false) in release, no Input.mouse_mode touch.
- In _ready extend PanelContainer layout: keep StyleBoxFlat bg 0,0,0,0.7, mouse_filter IGNORE, layer 150, offset 20,20,420,200 expanded height ~320-380. Add VBoxContainer already holding _title_label plus live section (_live_label), HSeparator, ScrollContainer (custom_minimum_size.y ~140) containing _history_label. Follow hud-system CanvasLayer pattern, single theme override. Preserve register_system early-return on release.

Pattern: scaffold + hud-system CanvasLayer/PanelContainer/VBoxContainer.

Verify: existing 7 tests in test_debug_overlay.gd still pass via --headless --path . -s addons/gut/gut_cmdln.gd

### Step 2 — Per-frame polling + field-level diff

File: autoloads/debug_overlay.gd

- Retain dead_keys pruning loop: is_instance_valid check, then _systems.erase(k) and _prev_states.erase(k)
- For each sys_name in _systems: node = _systems[sys_name]; if !has_method("get_debug_state"): continue; var st:Dictionary = node.get_debug_state(); if typeof(st)!=TYPE_DICTIONARY: continue; var prev:Dictionary = _prev_states.get(sys_name, {}); if ! _prev_states.has(sys_name): _prev_states[sys_name]=st.duplicate(true); continue; # silent seed
- Diff: for key in st.keys(): if !prev.has(key) or prev[key] != st[key]: var old_s = str(prev.get(key,"<nil>")) if prev.has(key) else "<nil>"; var new_s=str(st[key]); var line="[%s] %s: %s %s -> %s" % [now, sys_name, key, old_s, new_s]; _history.append(line); if _history.size()>HISTORY_MAX: _history.remove_at(0)
- Also diff removed keys: for key in prev.keys(): if !st.has(key): line="[%s] %s: %s %s -> <removed>" % [now, sys_name, key, str(prev[key])]; _history.append(line); cap.
- Update snapshot: _prev_states[sys_name]=st.duplicate(true)
- Timestamp via helper func _get_timestamp()->String returning Time.get_time_string_from_system() (overridable in tests).

Pattern: shallow diff with !=, Dictionary.duplicate(true).

Verify: mock change state WAITING->APPROACHING yields exactly one history line "DangerManager: state WAITING -> APPROACHING"; two keys changed yields two lines.

### Step 3 — Render live key/values for focused system

File: autoloads/debug_overlay.gd

- Determine focused_name: sorted or insertion-order keys = _systems.keys(); clamp _focused_index; _focused_name = keys[_focused_index] if non-empty else ""
- Live render: var live_lines:Array[String]=[]; if _focused_name!="" and _systems.has(_focused_name): var n=_systems[_focused_name]; if n.has_method("get_debug_state"): var d:Dictionary=n.get_debug_state(); for k in d.keys(): live_lines.append("%s: %s" % [k, str(d[k])]); if live_lines.is_empty(): live_lines.append("(no debug state)"); _live_label.text="\n".join(live_lines); _title_label.text="DebugOverlay (F3) — %d systems — Focus: %s" % [_systems.size(), _focused_name]; _history_label.text="\n".join(_history)

Pattern: existing _title_label/_content_label update; hud-system label.

Verify: mock {health:10, state:ROAMING} -> live label contains both; change health 9 -> next frame updates.

### Step 4 — Cap at 200, timestamped

File: autoloads/debug_overlay.gd

- Already in Step 2: HISTORY_MAX=200, remove_at(0)/pop_front when >200.
- Timestamp stored at generation time, not render time.

Pattern: ring buffer; extract _get_timestamp() for test injection.

Verify: 250 synthetic changes -> size==200, oldest evicted, each entry matches regex \[.*\] Mock: .*->.*

### Step 5 — Optional exemplar get_debug_state on managers

Files (viewed): systems/danger/danger_manager.gd, systems/quota/quota_manager.gd, systems/quota/coin_manager.gd, systems/round/round_manager.gd, systems/shark_bait/shark_bait_manager.gd

- Example danger_manager.gd: func get_debug_state()->Dictionary: return {"state": State.keys()[current_state], "targeting_bait": _is_targeting_bait, "shark_visible": is_instance_valid(shark_node) and shark_node.visible, "spawn": spawn_position}
- quota_manager.gd: return {"shared_quota": shared_quota}
- coin_manager.gd: return {"coins": coins, "shark_bait_owned": shark_bait_owned}
- Keep pure, no side effects, snake_case keys.

Verify: dev_seagull_flow.tscn runtime F3 shows DangerManager state transitions auto-appearing in history without manual log.

Alternative minimal diff: skip this step, rely only on mocks.

### Step 6 — Tests (GUT)

File choices: tests/unit/test_debug_overlay.gd (extend) or new tests/unit/test_debug_overlay_history.gd (preferred). Config .gutconfig.json dirs ["res://tests/unit"], prefix test_, suffix .gd.

New tests (one assertion per test, extends GutTest, before_each autofree + add_child + await process_frame):

- test_get_debug_state_polling_renders_live_keys
- test_field_level_diff_produces_one_log_line_per_changed_field
- test_history_timestamped_and_capped_at_200
- test_no_history_when_state_unchanged
- test_missing_get_debug_state_is_noop
- test_pruning_clears_prev_snapshot
- test_first_seen_seed_is_silent

Pattern: godot-testing: assert_eq, assert_string_contains, watch_signals if adding signals. Follow existing file's gating on OS.is_debug_build().

Verify: Godot_v4.6.2-stable_win64.exe --headless --path . -s addons/gut/gut_cmdln.gd passes all.

### Step 7 — No regression on scaffold + full suite

Run full headless: C:\Godot\Godot_v4.6.2-stable_win64.exe --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gprefix=test_ -gsuffix=.gd — expect green for test_debug_overlay, test_danger_manager, test_seagull_manager, test_coin_manager etc. Verify F3 toggles without mouse_mode, autoload order after HLobbies unchanged.

---

## 9. Test Plan Summary

| File | Test | Proves |
|------|------|--------|
| test_debug_overlay_history.gd | test_get_debug_state_polling_renders_live_keys | verbatim render |
| same | test_field_level_diff_* | one line per changed field |
| same | test_history_timestamped_and_capped | timestamp + ring 200 |
| same | test_no_history_when_unchanged | idempotent |
| same | test_missing_get_debug_state | duck-typed safe |
| same | test_pruning_clears_prev | dead prune clears snapshot |
| same | test_first_seen_seed_is_silent | seed no spam |
| test_debug_overlay.gd (existing) | 7 existing tests | scaffold not regressed |

Manual: run dev_seagull_flow.tscn, press F3, observe live state + history without lobby.

---

## 10. Explicitly Out of Scope

- Tab/arrow focus cycling, highlight row — #221
- get_debug_actions / debug_action(id) / _debug_action_rpc any_peer — #221
- 1-9 triggers, global mapping — #221
- Clickable buttons, mouse_mode coordination
- Manual log_event API
- New systems/<name>/<name>_manager.gd or dev_<system>_flow.tscn
- Disk persistence (ConfigFile/JSON)
- Theming overhaul, addons/ changes

---

## 11. Verification Checklist

1. Step1 layout -> existing GUT green
2. Step2 diff -> test_field_level_diff passes
3. Step3 live panel -> test_get_debug_state polling passes
4. Step4 cap -> test_history_capped passes
5. Step5 exemplars -> manual dev_seagull_flow F3 shows lines
6. Full headless — zero failures
7. Manual spot: F3, mouse_mode unchanged, pruning, live focused, history 200

---

## 12. Risks

- Dictionary aliasing: must duplicate(true) snapshot
- Enum ints verbose: prefer State.keys()[state] string in managers
- Polling cost: <10 systems, cheap
- Timestamp nondeterminism: injectable _get_timestamp()

End of plan — awaiting clarification on Ambiguities before coding. If assumptions confirmed, begin Step1 on feature/220-live-state-auto-history.
