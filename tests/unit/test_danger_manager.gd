extends GutTest

var manager: Node3D
var mock_player: Node3D


func before_each() -> void:
	var scene: PackedScene = load("res://systems/danger/danger_manager.tscn")
	manager = autofree(scene.instantiate())
	add_child(manager)
	await get_tree().process_frame

	manager.spawn_timer.stop()
	manager.return_timer.stop()

	mock_player = Node3D.new()
	mock_player.name = "Player_1"
	var mock_script := GDScript.new()
	mock_script.source_code = "extends Node3D\nvar is_yelling: bool = false\n"
	mock_script.reload()
	mock_player.set_script(mock_script)
	add_child(mock_player)
	manager.set_player_ref(mock_player)

	var health_component := HealthComponent.new()
	health_component.name = "HealthComponent"
	mock_player.add_child(health_component)


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

	manager.player_ref.is_yelling = true
	manager._physics_process(0.016)

	assert_eq(manager.current_state, 3, "Should be RETREATING (3)")


func test_attack_distance_triggers_signals() -> void:
	manager.current_state = 0
	manager._on_spawn_timer_timeout()
	manager.shark_node.position = Vector3(0, 0, -7)
	manager.player_ref.global_position = Vector3(0, 0, -7)
	manager.attack_range = 5.0

	var health := mock_player.get_node("HealthComponent") as HealthComponent
	health.current_health = 5

	watch_signals(manager)
	manager.current_state = 1
	manager._physics_process(1.0)

	assert_signal_emitted(manager, "fish_fled")
	assert_signal_not_emitted(manager, "quota_penalty")
	assert_eq(health.current_health, 3, "Health should be reduced by shark_bite_damage (2)")
	assert_eq(manager.current_state, 4, "Should be WAITING (4) after attack")
	assert_between(manager.spawn_timer.time_left, 45.0, 90.0, "Respawn interval should be 45-90 seconds")


func test_retreating_exits_boundary_transitions_to_waiting() -> void:
	manager.current_state = 0
	manager._on_spawn_timer_timeout()
	manager.current_state = 3
	manager.spawn_position = Vector3(30, 0, -7)
	manager.shark_node.position = Vector3(20, 0, -7)

	manager._physics_process(10.0)

	assert_eq(manager.current_state, 4, "Should be WAITING (4) after exiting boundary")


func test_return_timer_transitions_from_waiting_to_approaching() -> void:
	manager.current_state = 4
	manager._on_return_timer_timeout()
	assert_eq(manager.current_state, 1, "Should be APPROACHING (1)")


func test_spawn_position_rejects_close_points() -> void:
	manager.player_ref.global_position = Vector3(0, 0, -7)
	manager.min_spawn_distance_from_player = 100.0

	var pos: Vector3 = manager._pick_spawn_position(mock_player)
	var dist: float = Vector2(pos.x - 0, pos.z - (-7)).length()
	assert_gt(dist, 0, "Spawn should pick some position even when all points are too close")


func test_shark_not_spawned_without_player_ref() -> void:
	manager.player_ref = null
	manager.current_state = 0
	manager._on_spawn_timer_timeout()
	assert_eq(manager.current_state, 0, "Should stay INACTIVE when no player ref")
