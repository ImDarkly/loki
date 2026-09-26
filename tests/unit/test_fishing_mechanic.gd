extends GutTest

var mechanic: Node3D
var zone_manager: Node3D

# Victim id 1 keeps the server pull on the local branch instead of rpc_id to a peer that never connects.
const VICTIM_ID := 1


func before_each() -> void:
	var scene = load("res://systems/fishing/fishing_mechanic.tscn")
	mechanic = autofree(scene.instantiate())
	add_child(mechanic)
	await get_tree().process_frame

	var zone_scene: PackedScene = load("res://systems/zones/zone_manager.tscn")
	zone_manager = autofree(zone_scene.instantiate())
	add_child(zone_manager)
	zone_manager.call("set_zones", [
		{"center": Vector3(0, 0, 0), "radius": 10.0}
	])


func test_fish_fled_during_bite_transitions_to_idle() -> void:
	mechanic.current_state = 3
	mechanic._active_zone_index = 0
	mechanic.personal_catch_count = 3

	watch_signals(mechanic)
	mechanic.on_fish_fled()

	assert_eq(mechanic.current_state, 0, "Should be IDLE (0) after fish_fled during BITE")
	assert_eq(mechanic.personal_catch_count, 3, "Personal catch should remain unchanged after fish_fled")
	assert_signal_emitted(mechanic, "reel_failure")


func test_fish_fled_during_idle_does_nothing() -> void:
	mechanic.current_state = 0
	mechanic.personal_catch_count = 3

	watch_signals(mechanic)
	mechanic.on_fish_fled()

	assert_eq(mechanic.current_state, 0, "Should remain IDLE (0)")
	assert_signal_not_emitted(mechanic, "reel_failure")


func test_cast_ignored_when_fishing_inactive() -> void:
	mechanic._cached_fishing_active = false
	mechanic.current_state = 0
	assert_false(mechanic.can_cast(), "can_cast should return false when fishing inactive")


func test_bite_timer_fires_when_fishing_inactive() -> void:
	mechanic.current_state = 2
	mechanic._active_zone_index = 0
	mechanic._cached_fishing_active = false
	mechanic.cast_target_position = Vector3(0, 0, 0)
	mechanic._on_bite_timer_timeout()
	assert_eq(mechanic.current_state, 3, "Should transition to BITE (3) regardless of fishing_active")


func test_bite_timer_uses_dead_zone_feedback_outside_zones() -> void:
	mechanic.current_state = 2
	mechanic.cast_target_position = Vector3(100, 0, 100)
	watch_signals(mechanic)
	mechanic._on_bite_timer_timeout()
	assert_eq(mechanic.current_state, 0, "Should return to IDLE (0) when outside every zone")
	assert_signal_not_emitted(mechanic, "bite_occurred")
	assert_eq(mechanic.catch_feedback_manager.feedback_label.text, "Nothing's biting...")


func test_bite_click_hooks_fish_starts_fight() -> void:
	mechanic.current_state = 3
	mechanic._active_zone_index = 0
	mechanic._bite_time = 0.0
	mechanic._is_fighting = false

	watch_signals(mechanic)

	Input.action_press("reel")
	mechanic._process(0.0)
	Input.action_release("reel")

	assert_true(mechanic._is_fighting, "BITE reel click should set _is_fighting = true")
	assert_eq(mechanic.current_state, 3, "Should remain in BITE (3) after hook")
	assert_between(mechanic._fight_target, 2.0, 8.0, "fight_target should be in [2.0, 8.0] range")
	assert_eq(mechanic._fight_progress, 0.0, "fight_progress should start at 0.0")


func test_bite_miss_window_1_second_causes_escape() -> void:
	mechanic.current_state = 3
	mechanic._active_zone_index = 0
	mechanic._bite_time = 0.0
	mechanic.personal_catch_count = 0
	mechanic._is_fighting = false

	watch_signals(mechanic)

	Input.action_release("reel")

	while mechanic._bite_time < 1.5:
		mechanic._process(0.5)
		if mechanic.current_state != 3:
			break

	assert_eq(mechanic.current_state, 0, "Should return to IDLE (0) after 1.0s miss window")
	assert_eq(mechanic.personal_catch_count, 0, "personal_catch_count should remain unchanged")
	assert_signal_emitted(mechanic, "reel_failure")


func test_fight_auto_catches_when_time_elapsed() -> void:
	mechanic.current_state = 3
	mechanic._is_fighting = true
	mechanic.personal_catch_count = 0
	mechanic._fight_target = 2.0
	mechanic._fight_progress = 1.9

	watch_signals(mechanic)

	mechanic.advance_fight(0.2)

	assert_eq(mechanic.current_state, 4, "Should transition to SUCCESS (4)")
	assert_eq(mechanic.personal_catch_count, 1, "personal_catch_count should increment")
	assert_signal_emitted(mechanic, "reel_success")
	assert_signal_emitted(mechanic, "personal_catch_changed")
	assert_false(mechanic._is_fighting, "_is_fighting should be false after catch")


func test_fight_does_not_auto_catch_before_target() -> void:
	mechanic.current_state = 3
	mechanic._is_fighting = true
	mechanic.personal_catch_count = 0
	mechanic._fight_target = 5.0
	mechanic._fight_progress = 0.0
	mechanic._escape_timer = 0.0
	mechanic.escape_time_threshold = 99.0

	watch_signals(mechanic)
	mechanic.advance_fight(2.0)

	assert_eq(mechanic.current_state, 3, "Should remain in BITE before target")
	assert_signal_not_emitted(mechanic, "reel_success")


func test_advance_fight_noop_when_not_fighting() -> void:
	mechanic.current_state = 3
	mechanic._is_fighting = false
	mechanic.personal_catch_count = 5
	mechanic._fight_target = 2.0
	mechanic._fight_progress = 0.0

	watch_signals(mechanic)
	mechanic.advance_fight(2.0)

	assert_eq(mechanic.current_state, 3, "Should remain in BITE")
	assert_signal_not_emitted(mechanic, "reel_success")


func test_escape_triggers_after_threshold() -> void:
	mechanic.current_state = 3
	mechanic._is_fighting = true
	mechanic._fight_target = 99.0
	mechanic.cast_target_position = Vector3(10, 0, 0)
	mechanic.escape_time_threshold = 0.5

	watch_signals(mechanic)
	mechanic.advance_fight(0.6)

	assert_eq(mechanic.current_state, 0, "Should be IDLE after escape")
	assert_signal_emitted(mechanic, "reel_failure")
	assert_signal_emitted(mechanic, "escape_launch")
	assert_false(mechanic._is_fighting, "_is_fighting should be false after escape")


func test_scroll_resets_escape_timer() -> void:
	mechanic.current_state = 3
	mechanic._is_fighting = true
	mechanic._fight_target = 99.0
	mechanic.escape_time_threshold = 1.0
	mechanic.cast_target_position = Vector3(10, 0, 0)

	watch_signals(mechanic)

	for i in 10:
		mechanic.advance_fight(0.2)
		mechanic.notify_scroll()

	assert_eq(mechanic.current_state, 3, "Should remain in BITE after prevented escape")
	assert_signal_not_emitted(mechanic, "reel_failure")


func test_telegraph_intensity_ramps_before_trigger() -> void:
	mechanic.current_state = 3
	mechanic._is_fighting = true
	mechanic._fight_target = 99.0
	mechanic.escape_time_threshold = 2.0
	mechanic._escape_timer = 0.0

	mechanic.advance_fight(1.0)
	assert_almost_eq(mechanic._telegraph_intensity, 0.5, 0.01, "Half threshold should give 0.5 intensity")

	mechanic.advance_fight(0.5)
	assert_almost_eq(mechanic._telegraph_intensity, 0.75, 0.01, "3/4 threshold should give 0.75 intensity")


func test_arc_velocity_lands_at_target() -> void:
	var start: Vector3 = Vector3(2, 1.6, 0)
	var target: Vector3 = Vector3(10, 0, 3)
	var duration: float = 0.5
	var gravity: float = 9.8
	var v: Vector3 = mechanic._compute_launch_velocity(start, target, duration, gravity)
	var g: Vector3 = Vector3(0, -gravity, 0)
	var pos: Vector3 = start + v * duration + 0.5 * g * duration * duration
	assert_eq(pos, target, "Arc should land at target at t=flight_duration")


func test_arc_starts_at_rod_tip() -> void:
	var start: Vector3 = Vector3(2, 1.6, 0)
	var target: Vector3 = Vector3(10, 0, 3)
	var duration: float = 0.5
	var gravity: float = 9.8
	var v: Vector3 = mechanic._compute_launch_velocity(start, target, duration, gravity)
	var pos: Vector3 = start + v * 0.0 + 0.5 * Vector3(0, -gravity, 0) * 0.0 * 0.0
	assert_eq(pos, start, "Arc should start at rod tip at t=0")


func test_arc_is_deterministic() -> void:
	var start: Vector3 = Vector3(2, 1.6, 0)
	var target: Vector3 = Vector3(10, 0, 3)
	var duration: float = 0.5
	var gravity: float = 9.8
	var t: float = duration * 0.3
	var v1: Vector3 = mechanic._compute_launch_velocity(start, target, duration, gravity)
	var v2: Vector3 = mechanic._compute_launch_velocity(start, target, duration, gravity)
	var g: Vector3 = Vector3(0, -gravity, 0)
	var pos1: Vector3 = start + v1 * t + 0.5 * g * t * t
	var pos2: Vector3 = start + v2 * t + 0.5 * g * t * t
	assert_eq(pos1, pos2, "Same inputs should produce identical intermediate positions")


func test_max_tether_range_export() -> void:
	assert_true("max_tether_range" in mechanic, "max_tether_range export should exist")
	assert_eq(mechanic.max_tether_range, 25.0, "max_tether_range should default to 25.0")
	mechanic.max_tether_range = 10.0
	assert_eq(mechanic.max_tether_range, 10.0, "max_tether_range should be tunable")


func test_hook_type_defaults_to_none() -> void:
	assert_eq(mechanic.hook_type, mechanic.HookType.NONE, "hook_type should default to NONE")


func test_detect_floating_player_null_when_not_player_parent() -> void:
	assert_null(mechanic._detect_floating_player(), "Should return null when parent is not a Player")


func test_try_cast_with_detection_fish_fallback() -> void:
	watch_signals(mechanic)
	mechanic.try_cast_with_detection(Vector3(10, 0, 0), 0.5)
	assert_eq(mechanic.hook_type, mechanic.HookType.FISH, "Fallback should set hook_type to FISH")
	assert_eq(mechanic.current_state, mechanic.State.CASTING, "Fallback should enter CASTING state")
	assert_null(mechanic._tether_target, "_tether_target should be null for fish hook")


func test_player_tether_detection_and_direct_hook() -> void:
	var container = autofree(Node3D.new())
	add_child(container)

	var p1 = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	p1.name = "Player_1"
	container.add_child(p1)
	p1.global_position = Vector3(0, 0, 0)

	var mech = p1.fishing_mechanic

	var p2 = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	p2.name = "Player_2"
	container.add_child(p2)
	p2.global_position = Vector3(0, 0, -5.0)
	p2.player_state = Player.PlayerState.ALIVE
	await get_tree().process_frame
	await get_tree().physics_frame

	# When p2 is ALIVE, _detect_floating_player should return null
	assert_null(mech._detect_floating_player(), "Should not detect ALIVE player")

	# When p2 is beyond range
	p2.global_position = Vector3(0, 0, -25.0)
	p2.player_state = Player.PlayerState.FLOATING
	await get_tree().process_frame
	await get_tree().physics_frame
	assert_null(mech._detect_floating_player(), "Should not detect FLOATING player beyond range")

	# Within range and FLOATING
	p2.global_position = Vector3(0, 0, -5.0)
	p2.player_state = Player.PlayerState.FLOATING
	await get_tree().process_frame
	await get_tree().physics_frame

	var detected = mech._detect_floating_player()
	assert_eq(detected, p2, "Should detect FLOATING player within range")

	# Test direct hook via try_cast_with_detection
	watch_signals(mech)
	mech.try_cast_with_detection(Vector3(10, 0, 0), 0.5)

	assert_eq(mech.hook_type, mech.HookType.PLAYER, "hook_type should be PLAYER on direct player hook")
	assert_true(mech._is_fighting, "_is_fighting should be true on direct player hook")
	assert_eq(mech._tether_target, p2, "_tether_target should be p2")
	assert_eq(mech.current_state, mech.State.BITE, "Direct hook should skip arc and enter BITE state")
	assert_signal_not_emitted(mech, "bite_occurred", "Should not emit bite_occurred signal on player direct hook")
	assert_null(mech.get_node("FishManager").get_fish(), "Should not spawn fish on player direct hook")
	assert_false(mech.bite_timer.time_left > 0, "bite_timer should be stopped")
	assert_false(mech.casting_timer.time_left > 0, "casting_timer should be stopped")

	# Test reset_for_restart clears hook_type and _tether_target
	mech.reset_for_restart()
	assert_eq(mech.hook_type, mech.HookType.NONE, "reset_for_restart should clear hook_type to NONE")
	assert_null(mech._tether_target, "reset_for_restart should clear _tether_target")


func test_player_hook_skips_escape_beyond_threshold() -> void:
	mechanic.current_state = 3
	mechanic.hook_type = mechanic.HookType.PLAYER
	mechanic._is_fighting = true
	mechanic._fight_target = 99.0
	mechanic._fight_progress = 0.0
	mechanic._escape_timer = 0.0
	mechanic.escape_time_threshold = 0.5
	mechanic.cast_target_position = Vector3(10, 0, 0)

	watch_signals(mechanic)
	mechanic.advance_fight(0.6)

	assert_eq(mechanic.current_state, 3, "PLAYER hook should remain in BITE past escape threshold")
	assert_true(mechanic._is_fighting, "_is_fighting should stay true for PLAYER hook past escape threshold")
	assert_signal_not_emitted(mechanic, "reel_failure")
	assert_signal_not_emitted(mechanic, "escape_launch")


func test_player_hook_catches_despite_elapsed_escape_time() -> void:
	mechanic.current_state = 3
	mechanic.hook_type = mechanic.HookType.PLAYER
	mechanic._is_fighting = true
	mechanic._fight_target = 2.0
	mechanic._fight_progress = 1.9
	mechanic._escape_timer = 0.4
	mechanic.escape_time_threshold = 0.5
	mechanic.cast_target_position = Vector3(10, 0, 0)

	watch_signals(mechanic)
	mechanic.advance_fight(0.2)

	assert_eq(mechanic._fight_progress, 1.9, "PLAYER hook should freeze _fight_progress (no auto-catch)")
	assert_true(mechanic._is_fighting, "_is_fighting should stay true for PLAYER hook")
	assert_eq(mechanic.current_state, 3, "PLAYER hook should remain in BITE")
	assert_eq(mechanic.hook_type, mechanic.HookType.PLAYER, "hook_type should stay PLAYER")
	assert_signal_not_emitted(mechanic, "reel_success")
	assert_signal_not_emitted(mechanic, "reel_failure")
	assert_signal_not_emitted(mechanic, "escape_launch")


func test_request_hook_rejects_when_attacker_busy() -> void:
	var container = autofree(Node3D.new())
	add_child(container)
	var p1 = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	p1.name = "Player_1"
	container.add_child(p1)
	await get_tree().process_frame
	p1.player_state = Player.PlayerState.ALIVE
	var mech = p1.fishing_mechanic
	mech.current_state = mech.State.BITE
	mech.hook_type = mech.HookType.FISH
	mech._is_fighting = true

	var saved_peer = multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = null
	watch_signals(mech)
	mech.request_hook_player(2)
	multiplayer.multiplayer_peer = saved_peer

	assert_eq(mech.current_state, mech.State.IDLE, "Busy attacker should be rejected back to IDLE")
	assert_eq(mech.hook_type, mech.HookType.NONE, "Busy attacker reject should clear hook_type")
	assert_signal_emitted(mech, "reel_failure")


func test_request_hook_rejects_when_attacker_not_alive() -> void:
	var container = autofree(Node3D.new())
	add_child(container)
	var p1 = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	p1.name = "Player_1"
	container.add_child(p1)
	await get_tree().process_frame
	p1.player_state = Player.PlayerState.FLOATING
	var mech = p1.fishing_mechanic
	mech.current_state = mech.State.IDLE
	mech.hook_type = mech.HookType.NONE
	mech._is_fighting = false

	var saved_peer = multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = null
	watch_signals(mech)
	mech.request_hook_player(2)
	multiplayer.multiplayer_peer = saved_peer

	assert_eq(mech.current_state, mech.State.IDLE, "Non-ALIVE attacker should stay IDLE after reject")
	assert_eq(mech.hook_type, mech.HookType.NONE, "Non-ALIVE attacker reject should keep hook_type NONE")
	assert_signal_emitted(mech, "reel_failure")


func test_request_hook_rejects_when_fishing_inactive() -> void:
	var container = autofree(Node3D.new())
	add_child(container)
	var p1 = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	p1.name = "Player_1"
	container.add_child(p1)
	await get_tree().process_frame
	p1.player_state = Player.PlayerState.ALIVE
	var mech = p1.fishing_mechanic
	mech.current_state = mech.State.IDLE
	mech.hook_type = mech.HookType.NONE
	mech._is_fighting = false
	mech._cached_fishing_active = false

	var saved_peer = multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = null
	watch_signals(mech)
	mech.request_hook_player(2)
	multiplayer.multiplayer_peer = saved_peer

	assert_eq(mech.current_state, mech.State.IDLE, "Inactive fishing should stay IDLE after reject")
	assert_eq(mech.hook_type, mech.HookType.NONE, "Inactive fishing reject should keep hook_type NONE")
	assert_signal_emitted(mech, "reel_failure")


func test_remote_transition_to_idle_clears_fighting() -> void:
	mechanic._is_fighting = true
	mechanic.hook_type = mechanic.HookType.PLAYER
	mechanic._handle_remote_transition(mechanic.State.IDLE)
	assert_false(mechanic._is_fighting, "Remote IDLE transition should clear _is_fighting")
	assert_eq(mechanic.hook_type, mechanic.HookType.NONE, "Remote IDLE transition should clear hook_type")


func _spawn_hook_pair(target_pos: Vector3) -> Array:
	var container = autofree(Node3D.new())
	add_child(container)
	var caster = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	caster.name = "Player_1"
	container.add_child(caster)
	caster.global_position = Vector3(0, 0, 0)
	var target = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	target.name = "Player_2"
	container.add_child(target)
	target.global_position = target_pos
	target.player_state = Player.PlayerState.FLOATING
	await get_tree().process_frame
	await get_tree().physics_frame
	return [caster, target]


func _start_fish_fight(caster_mech: Node3D, target_pos: Vector3) -> void:
	caster_mech.current_state = caster_mech.State.BITE
	caster_mech.hook_type = caster_mech.HookType.FISH
	caster_mech._is_fighting = true
	caster_mech._fight_target = 99.0
	caster_mech._fight_progress = 0.0
	caster_mech._escape_timer = 0.0
	caster_mech.cast_target_position = target_pos


func _start_player_hook(caster_mech: Node3D, target: Player) -> void:
	caster_mech.current_state = caster_mech.State.BITE
	caster_mech.hook_type = caster_mech.HookType.PLAYER
	caster_mech._tether_target = target
	caster_mech._is_fighting = true
	caster_mech._fight_target = 99.0
	caster_mech._fight_progress = 0.0


func test_tether_pop_fish_beyond_range() -> void:
	var pair = await _spawn_hook_pair(Vector3.ZERO)
	var caster: Player = pair[0]
	var caster_mech = caster.fishing_mechanic
	caster_mech.escape_time_threshold = 99.0
	_start_fish_fight(caster_mech, Vector3(caster_mech.max_tether_range + 5.0, 0, 0))

	watch_signals(caster_mech)
	caster_mech.advance_fight(0.1)

	assert_eq(caster_mech.current_state, caster_mech.State.IDLE, "Fish pop should return to IDLE")
	assert_eq(caster_mech.hook_type, caster_mech.HookType.NONE, "Fish pop should clear hook_type")
	assert_false(caster_mech._is_fighting, "_is_fighting should be false after fish pop")
	assert_signal_emitted(caster_mech, "reel_failure")
	assert_signal_not_emitted(caster_mech, "escape_launch", "Pop should not launch the fish")


func test_tether_pop_player_beyond_range() -> void:
	var pair = await _spawn_hook_pair(Vector3(30, 0, 0))
	var caster: Player = pair[0]
	var target: Player = pair[1]
	var caster_mech = caster.fishing_mechanic
	_start_player_hook(caster_mech, target)

	watch_signals(caster_mech)
	caster_mech._physics_process(0.1)

	assert_eq(caster_mech.current_state, caster_mech.State.IDLE, "Player pop should return to IDLE")
	assert_eq(caster_mech.hook_type, caster_mech.HookType.NONE, "Player pop should clear hook_type")
	assert_false(caster_mech._is_fighting, "_is_fighting should be false after player pop")
	assert_eq(target.player_state, Player.PlayerState.FLOATING, "Popped target should stay FLOATING")
	assert_signal_emitted(caster_mech, "reel_failure")


func test_tether_pop_retryable() -> void:
	var pair = await _spawn_hook_pair(Vector3.ZERO)
	var caster: Player = pair[0]
	var caster_mech = caster.fishing_mechanic
	caster_mech.escape_time_threshold = 99.0
	_start_fish_fight(caster_mech, Vector3(caster_mech.max_tether_range + 5.0, 0, 0))

	caster_mech.advance_fight(0.1)

	assert_true(caster_mech.can_cast(), "Pop should leave the rod immediately retryable")


func test_no_tether_pop_within_range() -> void:
	var pair = await _spawn_hook_pair(Vector3.ZERO)
	var caster: Player = pair[0]
	var caster_mech = caster.fishing_mechanic
	caster_mech.escape_time_threshold = 99.0
	_start_fish_fight(caster_mech, Vector3(10, 0, 0))

	watch_signals(caster_mech)
	caster_mech.advance_fight(0.5)

	assert_eq(caster_mech.current_state, caster_mech.State.BITE, "In-range fight should stay in BITE")
	assert_true(caster_mech._is_fighting, "In-range fight should keep _is_fighting")
	assert_signal_not_emitted(caster_mech, "reel_failure")


func test_escape_timer_regression_with_parent() -> void:
	var pair = await _spawn_hook_pair(Vector3.ZERO)
	var caster: Player = pair[0]
	var caster_mech = caster.fishing_mechanic
	caster_mech.escape_time_threshold = 0.5
	_start_fish_fight(caster_mech, Vector3(10, 0, 0))

	watch_signals(caster_mech)
	caster_mech.advance_fight(0.6)

	assert_eq(caster_mech.current_state, caster_mech.State.IDLE, "Escape should still return to IDLE")
	assert_signal_emitted(caster_mech, "reel_failure")
	assert_signal_emitted(caster_mech, "escape_launch", "In-range escape should still launch")


func test_rescue_complete_on_land() -> void:
	var pair = await _spawn_hook_pair(MapConfig.MAP_CENTER)
	var caster: Player = pair[0]
	var target: Player = pair[1]
	target._float_time = 29.0
	var caster_mech = caster.fishing_mechanic
	_start_player_hook(caster_mech, target)

	caster_mech._physics_process(0.1)

	assert_eq(target.player_state, Player.PlayerState.ALIVE, "Target on land should become ALIVE")
	assert_eq(target._float_time, 0.0, "Rescue should cancel the float timer")
	assert_false(target._entered_water_reported, "Rescue should clear water flags")
	assert_eq(caster_mech.current_state, caster_mech.State.IDLE, "Rescue should clear the hook to IDLE")
	assert_eq(caster_mech.hook_type, caster_mech.HookType.NONE, "Rescue should clear hook_type")


func test_no_rescue_in_water() -> void:
	var pair = await _spawn_hook_pair(Vector3(0, 0, -20))
	var caster: Player = pair[0]
	var target: Player = pair[1]
	var caster_mech = caster.fishing_mechanic
	_start_player_hook(caster_mech, target)

	var saved_peer = multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = null
	caster_mech._physics_process(0.1)
	multiplayer.multiplayer_peer = saved_peer

	assert_eq(target.player_state, Player.PlayerState.FLOATING, "Target in water should stay FLOATING")
	assert_true(caster_mech._is_fighting, "Hook in water should keep fighting")
	assert_eq(caster_mech.hook_type, caster_mech.HookType.PLAYER, "Hook in water should stay PLAYER")


func test_rescue_clears_hook_fighting_state() -> void:
	var pair = await _spawn_hook_pair(MapConfig.MAP_CENTER)
	var caster: Player = pair[0]
	var target: Player = pair[1]
	var caster_mech = caster.fishing_mechanic
	_start_player_hook(caster_mech, target)

	watch_signals(caster_mech)
	caster_mech._physics_process(0.1)

	assert_false(caster_mech._is_fighting, "_is_fighting should be false after rescue")
	assert_null(caster_mech._tether_target, "_tether_target should be null after rescue")
	assert_signal_emitted(caster_mech, "reel_failure")


func test_hooked_victim_shore_contact_stuck_rescues() -> void:
	var pair = await _spawn_hook_pair(MapConfig.MAP_CENTER + Vector3(MapConfig.ISLAND_RADIUS + 0.5, 0, 0))
	var caster: Player = pair[0]
	var target: Player = pair[1]
	var caster_mech = caster.fishing_mechanic
	_start_player_hook(caster_mech, target)

	caster_mech._physics_process(0.1)

	assert_eq(target.player_state, Player.PlayerState.ALIVE, "SHORE_CONTACT victim should become ALIVE")
	assert_eq(caster_mech.current_state, caster_mech.State.IDLE, "SHORE_CONTACT rescue should clear the hook to IDLE")
	assert_eq(caster_mech.hook_type, caster_mech.HookType.NONE, "SHORE_CONTACT rescue should clear hook_type")
	var flat := Vector2(target.global_position.x - MapConfig.MAP_CENTER.x, target.global_position.z - MapConfig.MAP_CENTER.z)
	assert_true(flat.length() <= MapConfig.ISLAND_RADIUS - 0.4, "SHORE_CONTACT rescue should snap the victim onto the deck")
	assert_true(target.global_position.y >= 0.0, "SHORE_CONTACT rescue should lift the victim to deck level")
	assert_eq(target.velocity, Vector3.ZERO, "SHORE_CONTACT rescue should zero victim velocity")


func test_shore_contact_inside_tolerance_rescues() -> void:
	var pair = await _spawn_hook_pair(MapConfig.MAP_CENTER + Vector3(MapConfig.ISLAND_RADIUS + 0.5, 0, 0))
	var caster: Player = pair[0]
	var target: Player = pair[1]
	var caster_mech = caster.fishing_mechanic
	_start_player_hook(caster_mech, target)

	caster_mech._physics_process(0.1)

	assert_eq(target.player_state, Player.PlayerState.ALIVE, "Victim inside SHORE_CONTACT tolerance should become ALIVE")
	assert_eq(caster_mech.hook_type, caster_mech.HookType.NONE, "Rescue inside tolerance should clear hook_type")


func test_shore_contact_outside_tolerance_keeps_fighting() -> void:
	var pair = await _spawn_hook_pair(MapConfig.MAP_CENTER + Vector3(MapConfig.ISLAND_RADIUS + 2.0, 0, 0))
	var caster: Player = pair[0]
	var target: Player = pair[1]
	var caster_mech = caster.fishing_mechanic
	_start_player_hook(caster_mech, target)

	var saved_peer = multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = null
	caster_mech._physics_process(0.1)
	multiplayer.multiplayer_peer = saved_peer

	assert_eq(target.player_state, Player.PlayerState.FLOATING, "Victim outside SHORE_CONTACT tolerance should stay FLOATING")
	assert_true(caster_mech._is_fighting, "Hook outside tolerance should keep fighting")
	assert_eq(caster_mech.hook_type, caster_mech.HookType.PLAYER, "Hook outside tolerance should stay PLAYER")


func test_pull_inversion_reduces_target_to_caster_distance() -> void:
	var pair = await _spawn_hook_pair(Vector3(10, 0, -20))
	var caster: Player = pair[0]
	var target: Player = pair[1]
	caster.global_position = Vector3(0, 0, -20)
	var caster_mech = caster.fishing_mechanic
	_start_player_hook(caster_mech, target)
	var initial := caster.global_position.distance_to(target.global_position)
	caster_mech._fight_initial_distance = initial
	caster_mech._pull_spike_timer = 0.3

	var saved_peer = multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = null
	var caster_pos := caster.global_position
	caster_mech._physics_process(0.1)
	multiplayer.multiplayer_peer = saved_peer

	var after := caster.global_position.distance_to(target.global_position)
	assert_lt(after, initial, "PLAYER hook pull should shrink target-to-caster distance")
	assert_eq(caster.global_position, caster_pos, "PLAYER hook pull should move the target, not the caster")


func test_water_fallback_sets_zone_and_bite_timer() -> void:
	mechanic.try_cast_with_detection(Vector3(0, 0, 0), 0.5)
	assert_eq(mechanic.hook_type, mechanic.HookType.FISH, "Water fallback should set hook_type to FISH")
	assert_eq(mechanic.current_state, mechanic.State.CASTING, "Water fallback should enter CASTING")

	mechanic._on_casting_timer_timeout()

	assert_eq(mechanic.current_state, mechanic.State.WAITING, "Water fallback should enter WAITING after flight")
	assert_eq(mechanic._active_zone_index, 0, "Water fallback inside a zone should record _active_zone_index")
	assert_true(mechanic.bite_timer.time_left > 0.0, "Water fallback inside a zone should start the BiteTimer")


func test_rescue_cancels_float_timeout() -> void:
	var pair = await _spawn_hook_pair(MapConfig.MAP_CENTER)
	var caster: Player = pair[0]
	var target: Player = pair[1]
	target._float_time = 29.0
	target._water_report_retry = 7
	target._fell_off_island_reported = true
	var caster_mech = caster.fishing_mechanic
	_start_player_hook(caster_mech, target)

	caster_mech._physics_process(0.1)

	assert_eq(target.player_state, Player.PlayerState.ALIVE, "Rescue should revive the victim before the float timeout")
	assert_eq(target._float_time, 0.0, "Rescue should cancel the float timer")
	assert_eq(target._water_report_retry, 0, "Rescue should clear water report retries")
	assert_false(target._fell_off_island_reported, "Rescue should clear the fell-off-island flag")


func test_hooked_floating_player_is_shark_target() -> void:
	var container = autofree(Node3D.new())
	add_child(container)
	var players = Node3D.new()
	players.name = "Players"
	container.add_child(players)
	var caster = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	caster.name = "Player_1"
	players.add_child(caster)
	caster.global_position = Vector3(0, 0, -20)
	var target = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	target.name = "Player_2"
	players.add_child(target)
	target.global_position = Vector3(8, 0, -20)
	target.player_state = Player.PlayerState.FLOATING
	var danger = autofree(load("res://systems/danger/danger_manager.tscn").instantiate())
	danger.name = "DangerManager"
	container.add_child(danger)
	await get_tree().process_frame
	await get_tree().physics_frame

	_start_player_hook(caster.fishing_mechanic, target)

	var nodes = danger._get_player_nodes()
	assert_has(nodes, target, "Hooked FLOATING victim should stay a shark target")
	assert_not_null(danger._get_nearest_player(), "Shark should find a target while a victim is hooked")


func _spawn_peer_player(parent: Node, node_name: String, pos: Vector3, state: Player.PlayerState) -> Player:
	var p = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	p.name = node_name
	parent.add_child(p)
	p.global_position = pos
	p.player_state = state
	await get_tree().process_frame
	await get_tree().physics_frame
	(p.get_node("SlapComponent") as SlapComponent)._players_container = parent
	return p


func test_hook_request_peer_round_trip() -> void:
	var saved_peer = multiplayer.multiplayer_peer
	var server_peer := ENetMultiplayerPeer.new()
	var client_peer := ENetMultiplayerPeer.new()
	var chosen_port := -1
	for port in [37971, 37972, 37973, 37974]:
		if server_peer.create_server(port, 2) == OK:
			chosen_port = port
			break
		server_peer = ENetMultiplayerPeer.new()
	assert_ne(chosen_port, -1, "should bind an ENet server port")
	client_peer.create_client("127.0.0.1", chosen_port)

	var server_root := Node3D.new()
	server_root.name = "ServerRoot"
	add_child(server_root)
	var client_root := Node3D.new()
	client_root.name = "ClientRoot"
	add_child(client_root)

	var server_mp := SceneMultiplayer.new()
	server_mp.multiplayer_peer = server_peer
	var client_mp := SceneMultiplayer.new()
	client_mp.multiplayer_peer = client_peer
	get_tree().set_multiplayer(server_mp, server_root.get_path())
	get_tree().set_multiplayer(client_mp, client_root.get_path())

	var server_players := Node3D.new()
	server_players.name = "Players"
	server_root.add_child(server_players)
	var client_players := Node3D.new()
	client_players.name = "Players"
	client_root.add_child(client_players)

	var frames := 0
	while frames < 120 and (client_mp.get_unique_id() == 1 or server_mp.get_peers().is_empty()):
		await get_tree().process_frame
		frames += 1
	assert_ne(client_mp.get_unique_id(), 1, "client should obtain a unique id from server handshake")
	assert_true(server_mp.get_peers().has(client_mp.get_unique_id()), "server should see the connected client")

	var client_id := client_mp.get_unique_id()
	# Spawn the client copies before the server victim: the server holds
	# Player_1's authority, so its sync broadcasts need the client's Player_1
	# to exist first, otherwise the engine logs "Failed to get path from RPC".
	var server_caster := await _spawn_peer_player(server_players, "Player_%d" % client_id, Vector3(0, 0, -20), Player.PlayerState.ALIVE)
	var client_caster := await _spawn_peer_player(client_players, "Player_%d" % client_id, Vector3(0, 0, -20), Player.PlayerState.ALIVE)
	var client_victim := await _spawn_peer_player(client_players, "Player_%d" % VICTIM_ID, Vector3(5, 0, -20), Player.PlayerState.FLOATING)
	var server_victim := await _spawn_peer_player(server_players, "Player_%d" % VICTIM_ID, Vector3(5, 0, -20), Player.PlayerState.FLOATING)

	# The void has no floor, so everyone fell while spawning: re-pin positions
	# and states right before the request so the caster is ALIVE on execution.
	server_caster.global_position = Vector3(0, 0, -20)
	server_victim.global_position = Vector3(5, 0, -20)
	client_caster.global_position = Vector3(0, 0, -20)
	client_victim.global_position = Vector3(5, 0, -20)
	server_caster.velocity = Vector3.ZERO
	server_victim.velocity = Vector3.ZERO
	client_caster.velocity = Vector3.ZERO
	client_victim.velocity = Vector3.ZERO
	server_caster.player_state = Player.PlayerState.ALIVE
	client_caster.player_state = Player.PlayerState.ALIVE
	server_victim.player_state = Player.PlayerState.FLOATING
	client_victim.player_state = Player.PlayerState.FLOATING
	# Remote ALIVE players run with physics off; without this the server copy
	# broadcasts authority-mode _sync_transform the server may not send.
	server_caster.set_physics_process(false)

	var server_mech = server_caster.fishing_mechanic
	var client_mech = client_caster.fishing_mechanic
	server_mech._cached_fishing_active = true
	assert_eq(server_mech.hook_type, server_mech.HookType.NONE, "server rod should start unhooked")

	client_mech.request_hook_player.rpc_id(1, VICTIM_ID)

	frames = 0
	while frames < 120 and server_mech.hook_type != server_mech.HookType.PLAYER:
		await get_tree().process_frame
		frames += 1

	assert_eq(server_mech.hook_type, server_mech.HookType.PLAYER, "server should hook the floating victim on valid request")
	assert_eq(server_mech._tether_target, server_victim, "server tether should point at the victim")
	assert_true(server_mech._is_fighting, "server should be fighting after hook")
	assert_eq(server_mech.current_state, server_mech.State.BITE, "server should enter BITE after hook")

	frames = 0
	while frames < 120 and client_mech.current_state != client_mech.State.BITE:
		await get_tree().process_frame
		frames += 1
	assert_eq(client_mech.current_state, client_mech.State.BITE, "client should converge via _sync_fishing_state")
	assert_eq(client_mech.cast_target_position, server_mech.cast_target_position, "client should converge via _sync_cast_target")

	server_peer.close()
	client_peer.close()
	get_tree().set_multiplayer(null, server_root.get_path())
	get_tree().set_multiplayer(null, client_root.get_path())
	server_root.queue_free()
	client_root.queue_free()
	multiplayer.multiplayer_peer = saved_peer

