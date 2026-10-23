# Issue #350 verification

Date: 2026-10-23. Base: master `eb5880d`. Tier: standard.

## Change

The stale suite assumed distance-based fish movement, island water sweeps, and generation-based fish RPCs that are absent from the shipped implementation. Replaced it with six deterministic real-scene tests for elapsed fight progress, visual interpolation, scroll timer reset, postponed escape, escape cleanup, and one catch award. Production gameplay is unchanged.

Scoped verification now checks for the selected script heading and positive executed-test totals and rejects missing, ignored, skipped, and empty scripts. Existing parse-error detection and full-suite pending behavior remain in place.

## Checks actually run

- `scripts/verify.ps1 -Tier standard`: import, load, and focused GUT green; 6 tests, 38 assertions.
- `scripts/verify.ps1 -Tier standard -Final`: boot green.
- `git diff --check`: green. Independent standard reviewer: approve.
- Original focused GUT invocation: exit 0 despite parse errors, ignored script, and no matching script. The old gate also reported GREEN for a nonexistent selected script.
- Four temporary selected-script cases (missing file, explicitly skipped script, empty GutTest, malformed GDScript): GUT exit 0 in every case; updated gate exit 1 in every case. Temporary fixtures removed.

## Full-suite comparison

Same ordered test files, same runtime and ignored prerequisites; baseline excludes only fish-tug. Other test and production sources match master. The baseline manifest has 42 files, including one helper that does not extend GutTest, so 41 scripts execute. Branch adds the repaired fish-tug script.

| Run | Scripts | Tests | Passed | Failed | Pending |
| --- | ---: | ---: | ---: | ---: | ---: |
| Baseline excluding fish-tug | 41 | 663 | 639 | 23 | 1 |
| Branch including fish-tug | 42 | 669 | 645 | 23 | 1 |

Exact failure-name comparison: **0 added, 0 missing**, same 23 failures as tracker #351. No fish-tug parse errors in the repaired run. The pending mouse-capture test requires a rendered display. Both full-suite processes remained alive after their summaries and required termination; no successful process exit is claimed.

Commands:

```powershell
# Baseline: dirs=[], tests=sorted tests/unit/test_*.gd except test_fish_tug.gd,
# log_level=1, should_exit=true in the ignored manifest.
Godot_v4.6.2-stable_win64.exe --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.godot/350-baseline-config.json
Godot_v4.6.2-stable_win64.exe --headless --path . -s addons/gut/gut_cmdln.gd -glog=1
```

## Independent baseline failures

- `tests/unit/test_architecture_guardrails.gd::test_no_bare_get_node_on_root_paths`
- `tests/unit/test_architecture_guardrails.gd::test_no_unread_export_vars_in_systems`
- `tests/unit/test_fireplace.gd::test_purchase_shows_notification`
- `tests/unit/test_fishing_mechanic.gd::test_ambient_fish_shadows_local_only`
- `tests/unit/test_fishing_mechanic.gd::test_ambient_shadows_ignore_bobber_drift`
- `tests/unit/test_fishing_mechanic.gd::test_ambient_shadows_spawn_at_zone_center_not_bobber`
- `tests/unit/test_fishing_mechanic.gd::test_bite_miss_window_1_second_causes_escape`
- `tests/unit/test_fishing_mechanic.gd::test_fish_fled_during_bite_transitions_to_idle`
- `tests/unit/test_fishing_mechanic.gd::test_idle_bite_timeout_preserves_bobber_clears_shadows`
- `tests/unit/test_fishing_mechanic.gd::test_in_zone_cast_uses_full_bite_delay_range`
- `tests/unit/test_fishing_mechanic.gd::test_water_fallback_sets_zone_and_bite_timer`
- `tests/unit/test_pause_menu.gd::test_close_menu`
- `tests/unit/test_pause_menu.gd::test_mute_button_toggles_voice_chat_and_updates_text`
- `tests/unit/test_pause_menu.gd::test_open_menu`
- `tests/unit/test_pause_menu.gd::test_open_menu_refreshes_mute_label`
- `tests/unit/test_pause_menu.gd::test_pause_toggled_signal`
- `tests/unit/test_pause_menu.gd::test_single_player_fallback_scan_path`
- `tests/unit/test_pause_menu.gd::test_tree_paused_stays_false`
- `tests/unit/test_pause_menu.gd::test_ui_cancel_toggles`
- `tests/unit/test_restart_persistence.gd::test_restart_closes_pause_menu_and_emits_pause_toggled_false`
- `tests/unit/test_seagull_manager.gd::test_player_throw_out_of_range_no_repel`
- `tests/unit/test_seagull_manager.gd::test_player_throw_repels_seagull_in_range`
- `tests/unit/test_shop_ui.gd::test_successful_fireplace_buy_updates_coin_label`

## Environment and retained evidence

Godot 4.6.2; GUT 9.6.0. Initial diagnostic full runs were aborted after finding incomplete ignored prerequisites; they are not the comparison above. Installed the documented fish, rod, character, animation, shark, and rock assets from existing local worktrees, then imported before the completed comparison. Fish and animation hashes match ASSETS.md. No assets or credentials enter the diff.

Raw focused, baseline, branch, gate, and negative-case logs are retained locally under `.godot/350-evidence/`; the ordered manifest and parsed comparison are `.godot/350-baseline-config.json` and `.godot/350-comparison.json`. These local artifacts are ignored.

Attempt 1 | standard | import/load/focused/review/boot | green.
Full-suite limitation | same 23 baseline failures and 1 pending; process shutdown still tracked by #351.

Suggestion for AGENTS.md: require checking ignored asset prerequisites against ASSETS.md before starting full-suite comparisons.
