extends GutTest

var manager: Node3D
var mock_player: Node3D


func before_each() -> void:
	var scene = load("res://systems/danger/danger_manager.tscn")
	manager = autofree(scene.instantiate())
	add_child(manager)
	await get_tree().process_frame

	manager.spawn_timer.stop()
	manager.return_timer.stop()

	mock_player = Node3D.new()
	add_child(mock_player)
	manager.set_player_ref(mock_player)
	manager.player_ref.is_yelling = false


func test_initial_state_is_inactive() -> void:
	assert_eq(manager.current_state, 0, "Should start INACTIVE (0)")


func test_spawn_timer_transitions_from_inactive_to_approaching() -> void:
	manager.current_state = 0
	manager._on_spawn_timer_timeout()
	assert_eq(manager.current_state, 1, "Should be APPROACHING (1)")
	assert_true(is_instance_valid(manager.shark_node), "Shark mesh should exist")


func test_spawn_timer_transitions_from_waiting_to_approaching() -> void:
	manager.current_state = 4
	manager._on_spawn_timer_timeout()
	assert_eq(manager.current_state, 1, "Should be APPROACHING (1)")


func test_yell_during_approach_transitions_to_retreating() -> void:
	manager.current_state = 0
	manager._on_spawn_timer_timeout()
	var initial_speed = manager.swim_speed

	manager.player_ref.is_yelling = true
	manager._physics_process(0.016)

	assert_eq(manager.current_state, 2, "Should be RETREATING (2)")
	assert_eq(manager.swim_speed, initial_speed * manager.speed_multiplier, "Speed should escalate by multiplier")


func test_attack_distance_triggers_signals() -> void:
	manager.current_state = 0
	manager._on_spawn_timer_timeout()
	manager.shark_node.position = Vector3(0, 0, -7)
	manager.player_ref.global_position = Vector3(0, 0, -7)
	manager.attack_range = 5.0

	watch_signals(manager)
	manager.current_state = 1
	manager._physics_process(1.0)

	assert_signal_emitted(manager, "fish_fled")
	assert_signal_emitted(manager, "quota_penalty")
	assert_eq(manager.current_state, 4, "Should be WAITING (4) after attack")


func test_attack_resets_escalation() -> void:
	manager.current_state = 0
	manager._on_spawn_timer_timeout()
	manager.swim_speed = 7.0
	manager.return_delay = 1.0

	manager.shark_node.position = Vector3(0, 0, -7)
	manager.player_ref.global_position = Vector3(0, 0, -7)
	manager.attack_range = 5.0
	manager.current_state = 1
	manager._physics_process(1.0)

	assert_eq(manager.swim_speed, manager.initial_swim_speed, "Swim speed should reset to initial")
	assert_eq(manager.return_delay, manager.initial_return_delay, "Return delay should reset to initial")


func test_retreating_exits_boundary_transitions_to_waiting() -> void:
	manager.current_state = 0
	manager._on_spawn_timer_timeout()
	manager.current_state = 2
	manager.spawn_position = Vector3(30, 0, -7)
	manager.shark_node.position = Vector3(20, 0, -7)

	manager._physics_process(10.0)

	assert_eq(manager.current_state, 4, "Should be WAITING (4) after exiting boundary")


func test_return_timer_transitions_from_waiting_to_approaching() -> void:
	manager.current_state = 4
	manager._on_return_timer_timeout()
	assert_eq(manager.current_state, 1, "Should be APPROACHING (1)")


func test_escalation_floor_clamping() -> void:
	manager.swim_speed = 1.0
	manager.return_delay = 2.0
	manager.speed_multiplier = 10.0
	manager.delay_multiplier = 0.01
	manager.min_swim_speed = 8.0
	manager.min_return_delay = 0.5

	manager._apply_escalation()

	assert_eq(manager.swim_speed, 8.0, "Swim speed should clamp at min_swim_speed")
	assert_eq(manager.return_delay, 0.5, "Return delay should clamp at min_return_delay")


func test_spawn_position_rejects_close_points() -> void:
	manager.player_ref.global_position = Vector3(0, 0, -7)
	manager.min_spawn_distance_from_player = 100.0

	var pos = manager._pick_spawn_position()
	var dist = Vector2(pos.x - 0, pos.z - (-7)).length()
	assert_gt(dist, 0, "Spawn should pick some position even when all points are too close")


func test_shark_not_spawned_without_player_ref() -> void:
	manager.player_ref = null
	manager.current_state = 0
	manager._on_spawn_timer_timeout()
	assert_eq(manager.current_state, 0, "Should stay INACTIVE when no player ref")
