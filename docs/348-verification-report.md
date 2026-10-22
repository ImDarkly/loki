# #348 verification comparison

Date: 2026-10-22. Baseline: clean origin/master at `2c21fdff555ff965c44b987464ceace6c719e413`.

Both full runs use the same ordered [41-file manifest](348-suite-manifest.json), excluding only `test_fish_tug.gd` (#350). GUT executes 40 scripts; one manifest entry is a helper, not a GutTest. The tracked verify script was copied to a temporary file solely to set its worktree root and pass this GUT config to the full-suite command; no tracked gate code changed.

| Run | Tests | Passed | Failed | Pending |
|---|---:|---:|---:|---:|
| Clean master | 645 | 621 | 23 | 1 |
| #348 before correction | 654 | 627 | 26 | 1 |
| #348 after correction | 654 | 629 | 24 | 1 |

All 23 master failures occur on both #348 runs. Baseline maintenance: https://github.com/ImDarkly/loki/issues/351; fish-tug is its native sub-issue #350.

## Clean master failing tests (23)

- `test_architecture_guardrails.gd::test_no_bare_get_node_on_root_paths`
- `test_architecture_guardrails.gd::test_no_unread_export_vars_in_systems`
- `test_fireplace.gd::test_purchase_shows_notification`
- `test_fishing_mechanic.gd::test_ambient_fish_shadows_local_only`
- `test_fishing_mechanic.gd::test_ambient_shadows_ignore_bobber_drift`
- `test_fishing_mechanic.gd::test_ambient_shadows_spawn_at_zone_center_not_bobber`
- `test_fishing_mechanic.gd::test_bite_miss_window_1_second_causes_escape`
- `test_fishing_mechanic.gd::test_fish_fled_during_bite_transitions_to_idle`
- `test_fishing_mechanic.gd::test_idle_bite_timeout_preserves_bobber_clears_shadows`
- `test_fishing_mechanic.gd::test_in_zone_cast_uses_full_bite_delay_range`
- `test_fishing_mechanic.gd::test_water_fallback_sets_zone_and_bite_timer`
- `test_pause_menu.gd::test_close_menu`
- `test_pause_menu.gd::test_mute_button_toggles_voice_chat_and_updates_text`
- `test_pause_menu.gd::test_open_menu`
- `test_pause_menu.gd::test_open_menu_refreshes_mute_label`
- `test_pause_menu.gd::test_pause_toggled_signal`
- `test_pause_menu.gd::test_single_player_fallback_scan_path`
- `test_pause_menu.gd::test_tree_paused_stays_false`
- `test_pause_menu.gd::test_ui_cancel_toggles`
- `test_restart_persistence.gd::test_restart_closes_pause_menu_and_emits_pause_toggled_false`
- `test_seagull_manager.gd::test_player_throw_out_of_range_no_repel`
- `test_seagull_manager.gd::test_player_throw_repels_seagull_in_range`
- `test_shop_ui.gd::test_successful_fireplace_buy_updates_coin_label`

## Corrected #348 failing tests (24)

- `test_architecture_guardrails.gd::test_no_bare_get_node_on_root_paths`
- `test_architecture_guardrails.gd::test_no_unread_export_vars_in_systems`
- `test_fireplace.gd::test_purchase_shows_notification`
- `test_fishing_mechanic.gd::test_ambient_fish_shadows_local_only`
- `test_fishing_mechanic.gd::test_ambient_shadows_ignore_bobber_drift`
- `test_fishing_mechanic.gd::test_ambient_shadows_spawn_at_zone_center_not_bobber`
- `test_fishing_mechanic.gd::test_bite_miss_window_1_second_causes_escape`
- `test_fishing_mechanic.gd::test_fish_fled_during_bite_transitions_to_idle`
- `test_fishing_mechanic.gd::test_idle_bite_timeout_preserves_bobber_clears_shadows`
- `test_fishing_mechanic.gd::test_in_zone_cast_uses_full_bite_delay_range`
- `test_fishing_mechanic.gd::test_water_fallback_sets_zone_and_bite_timer`
- `test_pause_menu.gd::test_close_menu`
- `test_pause_menu.gd::test_mute_button_toggles_voice_chat_and_updates_text`
- `test_pause_menu.gd::test_open_menu`
- `test_pause_menu.gd::test_open_menu_refreshes_mute_label`
- `test_pause_menu.gd::test_pause_toggled_signal`
- `test_pause_menu.gd::test_single_player_fallback_scan_path`
- `test_pause_menu.gd::test_tree_paused_stays_false`
- `test_pause_menu.gd::test_ui_cancel_toggles`
- `test_player_fishing_animation_network.gd::test_server_replicates_owner_state_late_join_reset_and_rejects_spoofs`
- `test_restart_persistence.gd::test_restart_closes_pause_menu_and_emits_pause_toggled_false`
- `test_seagull_manager.gd::test_player_throw_out_of_range_no_repel`
- `test_seagull_manager.gd::test_player_throw_repels_seagull_in_range`
- `test_shop_ui.gd::test_successful_fireplace_buy_updates_coin_label`

## Difference and investigation

The original three branch-only test names were:

- `test_map_config.gd::test_ground_top_faces_have_upward_normals`
- `test_player_fishing_animation_network.gd::test_server_replicates_owner_state_late_join_reset_and_rejects_spoofs`
- `test_zone_manager.gd::test_scare_interrupts_bite_in_zone_that_cannot_move`

The first and third are fixed. One raw test-name difference remains after correction: `test_player_fishing_animation_network.gd::test_server_replicates_owner_state_late_join_reset_and_rejects_spoofs`.

Its state replication, spoof rejection, late-join, and reset assertions all pass, but an asynchronous EOS error is recorded against it: `Parameter "p_lobby_details" is null.`

A diagnostic on clean master reproduces the same error without any #348 code: run the unchanged `test_lobby.gd`, then an ignored diagnostic GutTest that only waits 15 seconds. `test_candidate_pick_clears_pending_pool` creates `HLobby.new()` and calls the real candidate-pick path; anonymous login resumes later and attempts to join using that empty lobby. Stack: `EOS.Lobby.join_lobby` -> `HLobbies.join_async` -> `NetworkManager._join_selected_lobby` -> `join_candidate` -> `_ensure_eos_ready_async`. Result: 12 existing lobby tests pass; the drain test receives the null-lobby engine error. This is evidence of baseline asynchronous work leaking into later test attribution, not a silent removal from the raw difference.

No lobby, EOS, or fishing-animation code/test was changed. The raw full-suite difference remains visible alongside the clean-master diagnostic evidence.

## Corrections and checks

- Ground: one tiny triangle near the northwest bay/channel join had correct rendered winding but reversed extracted collision winding after `Mesh.get_faces()` quantized vertices to 0.0001 m. Shared land coordinates now use that precision before triangulation; no triangles are discarded.
- Regression checks every rendered and collision top/cliff face. Map 13/13 passes, with 3602 assertions.
- Both farthest-zone scare fixtures are valid water and inside their test scare radius. Zones 39/39 pass.
- Scoped import/load, danger, fishing, map, player, restart, rocks, bait, and zones pass. Seagull 25/27 has exactly its two clean-master failures. World sky passes separately after fail-fast stopped at seagull.
- Independent deep review and multiplayer audit approve the frozen implementation.
- Final boot passes; final full suite remains red with the totals above. Only fish-tug is excluded; baseline failures were executed.

## Limits and status

- Mouse-capture test is pending on both full runs because it requires a rendered display.
- Full runs report GUT exit 1, then remain running; owned processes were terminated after their final summaries. Totals come from GUT, not forced process status.
- `test_fish_tug.gd` is unchanged.
- Owner explicitly authorized push and PR after receiving the raw comparison and baseline asynchronous-error evidence. Full-suite verification remains red; that authorization does not turn it green.

- Isolated fishing-animation network verification passes 2/2 on #348, including all replication assertions. No test suppression or network fix was made.
- Fresh Compatibility captures after the collision fix assert fog enabled, CULL_BACK, shadows enabled, and normal bias 2.0. Overview and plaza screenshots were visually inspected. No live EOS multiplayer walkthrough or headless mouse-capture coverage was added.
