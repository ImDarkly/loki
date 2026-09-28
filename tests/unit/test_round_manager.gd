extends GutTest

var manager: Node3D

func before_each() -> void:
	var scene: PackedScene = load("res://systems/round/round_manager.tscn")
	manager = autofree(scene.instantiate())
	add_child(manager)
	await get_tree().process_frame

	manager.timer.stop()
	manager.round_active = true
	manager.fishing_active = true

func test_round_active_false_after_win() -> void:
	manager._end_round(true)
	assert_false(manager.round_active, "round_active should be false after win")

func test_round_active_false_after_fail() -> void:
	manager._end_round(false)
	assert_false(manager.round_active, "round_active should be false after fail")

func test_round_active_starts_true_when_host() -> void:
	manager = autofree(load("res://systems/round/round_manager.tscn").instantiate())
	add_child(manager)
	await get_tree().process_frame
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		assert_true(manager.round_active, "round_active should be true for host after ready")
	else:
		assert_false(manager.round_active, "round_active should be false for non-host")

func test_round_success_true_after_win() -> void:
	manager._end_round(true)
	assert_true(manager.round_success, "round_success should be true after win")

func test_round_success_false_after_fail() -> void:
	manager._end_round(false)
	assert_false(manager.round_success, "round_success should be false after fail")

func test_synced_state_emits_round_ended_on_transition() -> void:
	watch_signals(manager)
	manager._apply_synced_state(false, true)
	assert_signal_emitted(manager, "round_ended")
	assert_signal_emitted_with_parameters(manager, "round_ended", [true])

func test_synced_state_does_not_emit_on_no_transition() -> void:
	manager.round_active = false
	watch_signals(manager)
	manager._apply_synced_state(false, true)
	assert_signal_not_emitted(manager, "round_ended")

func test_synced_state_stores_success() -> void:
	manager._apply_synced_state(true, true)
	assert_true(manager.round_success)

func test_round_duration_has_default() -> void:
	assert_eq(manager.round_duration, 900.0, "Default round duration should be 900 seconds")

func test_apply_restart_sets_round_active_true() -> void:
	manager.round_active = false
	manager._apply_restart()
	assert_true(manager.round_active, "round_active should be true after apply_restart")

func test_apply_restart_sets_round_success_false() -> void:
	manager.round_success = true
	manager._apply_restart()
	assert_false(manager.round_success, "round_success should be false after apply_restart")

func test_apply_restart_resets_timer_stopped_on_client() -> void:
	manager.round_active = false
	manager.round_success = true
	manager._apply_restart()
	assert_true(manager.round_active)
	assert_false(manager.round_success)
	assert_true(manager.timer.is_stopped(), "timer should remain stopped on client after apply_restart")

func test_restart_round_resets_timer_and_active() -> void:
	manager._end_round(true)
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		manager.restart_round()
		assert_true(manager.round_active)
		assert_false(manager.timer.is_stopped(), "timer should be running after restart")
	else:
		assert_false(manager.round_active, "round_active should remain false for non-host")

func test_fishing_active_starts_true() -> void:
	assert_true(manager.fishing_active, "fishing_active should start true")

func test_timer_timeout_sets_fishing_active_false() -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		manager._on_timer_timeout()
		assert_false(manager.fishing_active, "fishing_active should be false after timer timeout")

func test_timer_timeout_does_not_end_round() -> void:
	watch_signals(manager)
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		manager._on_timer_timeout()
		assert_true(manager.round_active, "round_active should remain true after timer timeout")
	assert_signal_not_emitted(manager, "round_ended")

func test_restart_round_sets_fishing_active_true() -> void:
	manager.fishing_active = false
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		manager.restart_round()
		assert_true(manager.fishing_active, "fishing_active should be true after restart")
	else:
		assert_false(manager.fishing_active, "fishing_active should remain false for non-host")

func test_apply_restart_sets_fishing_active_true() -> void:
	manager.fishing_active = false
	manager._apply_restart()
	assert_true(manager.fishing_active, "fishing_active should be true after apply_restart")

func test_synced_state_stores_fishing_active() -> void:
	manager._apply_synced_state(true, false, false)
	assert_false(manager.fishing_active, "fishing_active should match synced value")


func test_get_debug_state_returns_expected_keys() -> void:
	var st = manager.get_debug_state()
	assert_true(st.has("round_active"))
	assert_true(st.has("round_success"))
	assert_true(st.has("fishing_active"))
	assert_true(st.has("time_left"))
	assert_eq(typeof(st["time_left"]), TYPE_INT)


func test_get_debug_actions_returns_five_actions() -> void:
	var acts = manager.get_debug_actions()
	assert_eq(acts.size(), 5)
	var ids = []
	for act in acts:
		ids.append(act["id"])
	assert_true(ids.has("pause_fishing"))
	assert_true(ids.has("resume_fishing"))
	assert_true(ids.has("restart_round"))
	assert_true(ids.has("add_time_30"))
	assert_true(ids.has("shave_time_30"))


func test_debug_actions_execution() -> void:
	manager.debug_action("pause_fishing")
	assert_false(manager.fishing_active)
	manager.timer.start(100.0)
	manager.debug_action("resume_fishing")
	assert_true(manager.fishing_active)

	manager.timer.start(100.0)
	var t_before = manager.timer.time_left
	manager.debug_action("add_time_30")
	assert_true(manager.timer.time_left > t_before)

	var t_after_add = manager.timer.time_left
	manager.debug_action("shave_time_30")
	assert_true(manager.timer.time_left < t_after_add)

	manager.debug_action("restart_round")
	assert_true(manager.round_active)
	assert_true(manager.fishing_active)

func test_resume_fishing_ignored_when_timer_stopped() -> void:
	manager.timer.stop()
	manager.fishing_active = false
	manager.debug_action("resume_fishing")
	assert_false(manager.fishing_active, "resume_fishing should not set fishing_active true when timer stopped")


func after_each() -> void:
	var main := get_node_or_null("/root/main")
	if main:
		var players := main.get_node_or_null("Players")
		if players:
			players.free()
		if main.get_child_count() == 0:
			main.free()


func _spawn_team(alive_states: Array) -> Node3D:
	var main := get_node_or_null("/root/main")
	if main == null:
		main = Node3D.new()
		main.name = "main"
		get_node("/root").add_child(main)
	var old := main.get_node_or_null("Players")
	if old:
		old.free()
	var players := Node3D.new()
	players.name = "Players"
	main.add_child(players)
	for i in alive_states.size():
		var p := Node3D.new()
		p.name = "Player_%d" % (i + 1)
		players.add_child(p)
		var hp := HealthComponent.new()
		hp.name = "HealthComponent"
		p.add_child(hp)
		if not alive_states[i]:
			hp.current_health = 0
	return players


func test_full_wipe_ends_round_as_failure() -> void:
	_spawn_team([false, false])
	watch_signals(manager)
	manager._on_wipe_grace_elapsed(manager._wipe_generation)
	assert_false(manager.round_active, "round_active should be false after full wipe")
	assert_false(manager.round_success, "round_success should be false after wipe")
	assert_signal_emitted_with_parameters(manager, "round_ended", [false])


func test_partial_death_does_not_end_round() -> void:
	_spawn_team([false, true])
	watch_signals(manager)
	manager._on_wipe_grace_elapsed(manager._wipe_generation)
	assert_true(manager.round_active, "round_active should stay true when a player is alive")
	assert_signal_not_emitted(manager, "round_ended")


func test_freed_player_excluded_from_wipe() -> void:
	var players := _spawn_team([true, false])
	players.get_child(1).free()
	watch_signals(manager)
	manager._on_wipe_grace_elapsed(manager._wipe_generation)
	assert_true(manager.round_active, "Freed dead player must not count toward a wipe")
	assert_signal_not_emitted(manager, "round_ended")


func test_wipe_grace_is_client_noop() -> void:
	_spawn_team([false, false])
	var saved_peer = manager.multiplayer.multiplayer_peer
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", 1)
	manager.multiplayer.multiplayer_peer = peer
	watch_signals(manager)
	manager._on_wipe_grace_elapsed(manager._wipe_generation)
	assert_true(manager.round_active, "Client must not end the round")
	assert_signal_not_emitted(manager, "round_ended")
	manager.multiplayer.multiplayer_peer = saved_peer


func test_restart_invalidates_in_flight_grace() -> void:
	_spawn_team([false, false])
	var stale_gen: int = manager._wipe_generation
	manager.restart_round()
	assert_true(manager.round_active, "Round should be active after restart")
	watch_signals(manager)
	manager._on_wipe_grace_elapsed(stale_gen)
	assert_true(manager.round_active, "Stale grace must not end the restarted round")
	assert_signal_not_emitted(manager, "round_ended")
