extends GutTest

var manager: Node3D
var storage_box: Node3D
var _parent: Node3D


func before_each() -> void:
	_parent = Node3D.new()
	_parent.name = "main"
	get_node("/root").add_child(autofree(_parent))

	storage_box = Node3D.new()
	storage_box.name = "StorageBox"
	storage_box.position = Vector3(3.5, -0.2, -1.5)
	_parent.add_child(storage_box)

	var scene: PackedScene = load("res://systems/danger/seagull_manager.tscn")
	manager = autofree(scene.instantiate())
	_parent.add_child(manager)
	await get_tree().process_frame

	manager.spawn_timer.stop()
	manager.return_timer.stop()


func after_each() -> void:
	_parent = null
	storage_box = null


func test_initial_state_is_inactive() -> void:
	assert_eq(manager.current_state, manager.State.INACTIVE, "Should start INACTIVE")


func test_spawn_creates_mesh() -> void:
	manager.current_state = manager.State.INACTIVE
	manager._on_spawn_timer_timeout()
	assert_eq(manager.current_state, manager.State.APPROACHING, "Should be APPROACHING")
	assert_true(is_instance_valid(manager.seagull_node), "Seagull mesh should exist")
	assert_true(manager.seagull_node.visible, "Seagull should be visible after spawn")
	assert_true(manager.seagull_node.mesh != null, "Seagull mesh resource should be assigned")
	var mat := manager.seagull_node.material_override as StandardMaterial3D
	assert_true(is_instance_valid(mat), "Seagull should have StandardMaterial3D")
	assert_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)


func test_spawn_at_fixed_altitude_on_perimeter() -> void:
	manager.current_state = manager.State.INACTIVE
	manager._on_spawn_timer_timeout()
	assert_almost_eq(manager.seagull_node.position.y, manager.flight_altitude, 0.001, "Seagull should spawn at flight_altitude")
	var flat_dist := Vector2(
		manager.seagull_node.position.x - MapConfig.MAP_CENTER.x,
		manager.seagull_node.position.z - MapConfig.MAP_CENTER.z
	).length()
	assert_almost_eq(flat_dist, MapConfig.FISHABLE_BAND_RADIUS, 0.01, "Spawn should be on fishable-band perimeter")


func test_approaching_advances_toward_storage_box() -> void:
	manager.current_state = manager.State.INACTIVE
	manager._on_spawn_timer_timeout()
	manager.current_state = manager.State.APPROACHING
	storage_box.global_position = Vector3(3.5, -0.2, -1.5)
	manager.seagull_node.position = Vector3(20, manager.flight_altitude, -7)
	var before_dist := Vector2(
		manager.seagull_node.position.x - storage_box.global_position.x,
		manager.seagull_node.position.z - storage_box.global_position.z
	).length()
	manager._physics_process(1.0)
	var after_dist := Vector2(
		manager.seagull_node.position.x - storage_box.global_position.x,
		manager.seagull_node.position.z - storage_box.global_position.z
	).length()
	assert_lt(after_dist, before_dist, "APPROACHING should advance toward StorageBox")
	assert_almost_eq(manager.seagull_node.position.y, manager.flight_altitude, 0.001, "Seagull should stay at fixed altitude while approaching")


func test_approaching_arrival_triggers_attack() -> void:
	manager.current_state = manager.State.INACTIVE
	manager._on_spawn_timer_timeout()
	manager.current_state = manager.State.APPROACHING
	storage_box.global_position = Vector3(3.5, -0.2, -1.5)
	manager.arrival_range = 2.0
	manager.seagull_node.position = Vector3(storage_box.global_position.x + 0.5, manager.flight_altitude, storage_box.global_position.z)
	manager._physics_process(0.1)
	assert_eq(manager.current_state, manager.State.WAITING, "Should be WAITING after attack at StorageBox")
	assert_false(manager.seagull_node.visible, "Seagull hidden after theft")


func test_repel_transitions_to_retreating_when_in_range() -> void:
	manager.current_state = manager.State.INACTIVE
	manager._on_spawn_timer_timeout()
	manager.current_state = manager.State.APPROACHING
	manager.seagull_node.position = Vector3(5, manager.flight_altitude, 0)
	manager.repel(Vector3(0, manager.flight_altitude, 0), Vector3(1, 0, 0))
	assert_eq(manager.current_state, manager.State.RETREATING, "Should be RETREATING after repel")


func test_repel_no_op_when_out_of_range() -> void:
	manager.current_state = manager.State.INACTIVE
	manager._on_spawn_timer_timeout()
	manager.current_state = manager.State.APPROACHING
	manager.seagull_node.position = Vector3(10, manager.flight_altitude, 0)
	manager.repel(Vector3(0, manager.flight_altitude + 5, 0), Vector3(1, 0, 0))
	assert_eq(manager.current_state, manager.State.APPROACHING, "Should stay APPROACHING after out-of-range repel")


func test_repel_no_op_when_not_approaching() -> void:
	manager.current_state = manager.State.INACTIVE
	manager._on_spawn_timer_timeout()
	manager.current_state = manager.State.RETREATING
	manager.seagull_node.position = Vector3(5, manager.flight_altitude, 0)
	manager.repel(Vector3(0, manager.flight_altitude, 0), Vector3(1, 0, 0))
	assert_eq(manager.current_state, manager.State.RETREATING, "Repel should be no-op when not APPROACHING")


func test_retreating_vanishes_at_spawn_position() -> void:
	manager.current_state = manager.State.INACTIVE
	manager._on_spawn_timer_timeout()
	manager.current_state = manager.State.RETREATING
	manager.spawn_position = MapConfig.MAP_CENTER + Vector3(MapConfig.FISHABLE_BAND_RADIUS - 1.0, manager.flight_altitude, 0)
	manager.spawn_position.y = manager.flight_altitude
	manager.seagull_node.position = Vector3(20, manager.flight_altitude, -7)
	manager._physics_process(10.0)
	assert_eq(manager.current_state, manager.State.WAITING, "Should be WAITING after reaching spawn")
	assert_false(manager.seagull_node.visible, "Seagull should be hidden after retreating")


func test_retreating_exits_boundary_transitions_to_waiting() -> void:
	manager.current_state = manager.State.INACTIVE
	manager._on_spawn_timer_timeout()
	manager.current_state = manager.State.RETREATING
	manager.spawn_position = Vector3(30, manager.flight_altitude, -7)
	manager.seagull_node.position = Vector3(20, manager.flight_altitude, -7)
	manager._physics_process(10.0)
	assert_eq(manager.current_state, manager.State.WAITING, "Should be WAITING after exiting FISHABLE_BAND_RADIUS")
	assert_false(manager.seagull_node.visible, "Seagull should be hidden after exiting band")


func test_return_timer_transitions_from_waiting_to_approaching() -> void:
	manager.current_state = manager.State.WAITING
	manager._on_return_timer_timeout()
	assert_eq(manager.current_state, manager.State.APPROACHING, "Should be APPROACHING after return timer")
	assert_true(is_instance_valid(manager.seagull_node), "Seagull mesh should exist after return")


func test_theft_applies_penalty() -> void:
	var quota = autofree(load("res://systems/quota/quota_manager.tscn").instantiate())
	quota.name = "QuotaManager"
	_parent.add_child(quota)
	quota.shared_quota = 5
	manager.theft_amount = 1
	manager.current_state = manager.State.INACTIVE
	manager._on_spawn_timer_timeout()
	manager.current_state = manager.State.APPROACHING
	storage_box.global_position = Vector3(3.5, -0.2, -1.5)
	manager.arrival_range = 2.0
	manager.seagull_node.position = Vector3(storage_box.global_position.x, manager.flight_altitude, storage_box.global_position.z)
	manager._physics_process(0.1)
	assert_eq(quota.shared_quota, 4, "Quota should drop by theft_amount")


func test_fishing_paused_forces_retreat_and_blocks_spawn() -> void:
	var script = GDScript.new()
	script.source_code = "extends Node3D\nvar fishing_active: bool = true\n"
	script.reload()
	var rm = Node3D.new()
	rm.set_script(script)
	rm.name = "RoundManager"
	_parent.add_child(autofree(rm))
	manager._round_manager = rm
	rm.fishing_active = true
	manager.current_state = manager.State.INACTIVE
	manager._on_spawn_timer_timeout()
	rm.fishing_active = false
	manager.current_state = manager.State.APPROACHING
	if not is_instance_valid(manager.seagull_node):
		manager._on_spawn_timer_timeout()
	manager.seagull_node.position = Vector3(10, manager.flight_altitude, 0)
	manager._physics_process(0.1)
	assert_eq(manager.current_state, manager.State.RETREATING, "Paused fishing should force retreat")
	manager.current_state = manager.State.WAITING
	manager._on_spawn_timer_timeout()
	assert_eq(manager.current_state, manager.State.WAITING, "Spawn blocked when fishing_active false")


func test_reset_for_restart() -> void:
	manager.current_state = manager.State.INACTIVE
	manager._on_spawn_timer_timeout()
	manager.current_state = manager.State.APPROACHING
	if not is_instance_valid(manager.seagull_node):
		manager._on_spawn_timer_timeout()
	manager.seagull_node.visible = true
	manager.reset_for_restart()
	assert_eq(manager.current_state, manager.State.INACTIVE)
	assert_false(manager.seagull_node.visible)
