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
	if manager.has_node("RoamTimer"):
		manager.get_node("RoamTimer").stop()


func after_each() -> void:
	_parent = null
	storage_box = null


func test_initial_state_is_inactive() -> void:
	assert_eq(manager.current_state, manager.State.INACTIVE, "Should start INACTIVE")


func test_spawn_creates_mesh() -> void:
	manager.current_state = manager.State.INACTIVE
	manager._on_spawn_timer_timeout()
	assert_eq(manager.current_state, manager.State.ROAMING, "Should be ROAMING (circling before dive)")
	assert_true(is_instance_valid(manager.seagull_node), "Seagull mesh should exist")
	assert_true(manager.seagull_node.visible, "Seagull should be visible after spawn")
	assert_true(manager.seagull_node.mesh != null, "Seagull mesh resource should be assigned")
	var mat := manager.seagull_node.material_override as StandardMaterial3D
	assert_true(is_instance_valid(mat), "Seagull should have StandardMaterial3D")
	assert_eq(mat.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)


func test_spawn_at_fixed_altitude_on_perimeter() -> void:
	manager.current_state = manager.State.INACTIVE
	manager._on_spawn_timer_timeout()
	assert_almost_eq(manager.seagull_node.position.y, manager.roaming_altitude, 0.001, "Seagull should spawn at roaming_altitude high")
	var flat_dist := Vector2(
		manager.seagull_node.position.x - storage_box.global_position.x,
		manager.seagull_node.position.z - storage_box.global_position.z
	).length()
	assert_almost_eq(flat_dist, manager.roam_radius, 0.5, "Spawn should circle StorageBox at roam_radius")


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
	assert_eq(manager.current_state, manager.State.ROAMING, "Should be ROAMING after return timer (circles before dive)")
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


func test_fishing_resumed_restarts_spawn_timer() -> void:
	var script = GDScript.new()
	script.source_code = "extends Node3D\nvar fishing_active: bool = false\n"
	script.reload()
	var rm = Node3D.new()
	rm.set_script(script)
	rm.name = "RoundManager"
	_parent.add_child(autofree(rm))
	manager._round_manager = rm
	rm.fishing_active = false
	manager._last_fishing_active = false
	manager.spawn_timer.stop()

	rm.fishing_active = true
	manager._physics_process(0.1)
	assert_false(manager.spawn_timer.is_stopped(), "Spawn timer should start when fishing resumes")


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


func test_reset_for_restart_hides_and_re_randomizes_timer() -> void:
	manager.current_state = manager.State.INACTIVE
	manager._on_spawn_timer_timeout()
	manager.current_state = manager.State.APPROACHING
	manager.return_timer.start(99)
	manager.get_node("RoamTimer").start(99)
	manager.seagull_node.visible = true
	manager.reset_for_restart()
	assert_eq(manager.current_state, manager.State.INACTIVE, "INACTIVE after reset")
	assert_false(manager.seagull_node.visible, "hidden after reset")
	assert_false(manager.spawn_timer.is_stopped(), "spawn_timer re-randomized")
	assert_true(manager.return_timer.is_stopped(), "return_timer stopped")
	assert_true(manager.get_node("RoamTimer").is_stopped(), "roam_timer stopped")


func _build_player_for_seagull(parent: Node3D) -> Player:
	var player_node := CharacterBody3D.new()
	player_node.name = "Player_1"
	var head := Node3D.new()
	head.name = "Head"
	player_node.add_child(head)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	head.add_child(camera)
	var hand_left := MeshInstance3D.new()
	hand_left.name = "HandLeft"
	head.add_child(hand_left)
	var hand_right := MeshInstance3D.new()
	hand_right.name = "HandRight"
	head.add_child(hand_right)
	var body_mesh := MeshInstance3D.new()
	body_mesh.name = "BodyMesh"
	player_node.add_child(body_mesh)
	var fishing_scene = load("res://systems/fishing/fishing_mechanic.tscn")
	var fishing_mechanic = fishing_scene.instantiate()
	fishing_mechanic.name = "FishingMechanic"
	player_node.add_child(fishing_mechanic)
	var voice_chat_manager := Node.new()
	voice_chat_manager.name = "VoiceChatManager"
	voice_chat_manager.set_script(load("res://systems/voice_chat/voice_chat_manager.gd"))
	player_node.add_child(voice_chat_manager)
	var health_component := HealthComponent.new()
	health_component.name = "HealthComponent"
	player_node.add_child(health_component)
	var sitting_heal := SittingHealComponent.new()
	sitting_heal.name = "SittingHeal"
	player_node.add_child(sitting_heal)
	var spectate_camera := Node3D.new()
	spectate_camera.name = "SpectateCamera"
	player_node.add_child(spectate_camera)
	var spectate_cam_camera := Camera3D.new()
	spectate_cam_camera.name = "Camera3D"
	spectate_camera.add_child(spectate_cam_camera)
	player_node.set_script(load("res://entities/player/player.gd"))
	var p := player_node as Player
	parent.add_child(p)
	await get_tree().process_frame
	return p


func test_player_throw_repels_seagull_in_range() -> void:
	manager.current_state = manager.State.INACTIVE
	manager._on_spawn_timer_timeout()
	manager.current_state = manager.State.APPROACHING
	var player := await _build_player_for_seagull(_parent)
	autofree(player)
	player._seagull_manager_ref = manager
	player._danger_manager_ref = null
	player.camera.global_position = Vector3(0, manager.flight_altitude, 0)
	player.camera.look_at(Vector3(10, manager.flight_altitude, 0), Vector3.UP)
	manager.seagull_node.global_position = Vector3(5, manager.flight_altitude, 0)
	player.holding_rock = true
	var root := get_tree().root
	var rocks_before: Array[Node] = []
	for c in root.get_children():
		if c is RigidBody3D:
			rocks_before.append(c)
	player._throw_rock()
	for c in root.get_children():
		if c is RigidBody3D and c not in rocks_before:
			autofree(c)
	assert_eq(manager.current_state, manager.State.RETREATING, "Player rock throw in range -> RETREATING")


func test_player_throw_out_of_range_no_repel() -> void:
	manager.current_state = manager.State.INACTIVE
	manager._on_spawn_timer_timeout()
	manager.current_state = manager.State.APPROACHING
	var player := await _build_player_for_seagull(_parent)
	autofree(player)
	player._seagull_manager_ref = manager
	player._danger_manager_ref = null
	player.camera.global_position = Vector3(0, manager.flight_altitude, 0)
	player.camera.look_at(Vector3(10, manager.flight_altitude, 0), Vector3.UP)
	manager.seagull_node.global_position = Vector3(5, manager.flight_altitude + 5, 0)
	player.holding_rock = true
	var root := get_tree().root
	var rocks_before: Array[Node] = []
	for c in root.get_children():
		if c is RigidBody3D:
			rocks_before.append(c)
	player._throw_rock()
	for c in root.get_children():
		if c is RigidBody3D and c not in rocks_before:
			autofree(c)
	assert_eq(manager.current_state, manager.State.APPROACHING, "Out-of-range throw -> no repel")


func test_round_manager_restart_resets_seagull() -> void:
	var rm_scene: PackedScene = load("res://systems/round/round_manager.tscn")
	var rm = rm_scene.instantiate()
	rm.name = "RoundManager"
	var existing_rm := _parent.get_node_or_null("RoundManager")
	if existing_rm:
		_parent.remove_child(existing_rm)
		existing_rm.queue_free()
		await get_tree().process_frame
	_parent.add_child(autofree(rm))
	await get_tree().process_frame
	rm.timer.stop()
	manager.current_state = manager.State.INACTIVE
	manager._on_spawn_timer_timeout()
	manager.current_state = manager.State.APPROACHING
	manager.seagull_node.visible = true
	rm.restart_round()
	assert_eq(manager.current_state, manager.State.INACTIVE, "RoundManager restart -> INACTIVE")
	assert_false(manager.seagull_node.visible, "seagull hidden after restart")
	assert_false(manager.spawn_timer.is_stopped(), "spawn_timer restarted after restart")


func test_get_debug_state_returns_expected_keys() -> void:
	var st = manager.get_debug_state()
	assert_true(st.has("state"))
	assert_true(st.has("seagull_visible"))
	assert_true(st.has("spawn"))
	assert_true(st.has("spawn_timer_left"))
	assert_true(st.has("return_timer_left"))
	assert_true(st.has("roam_timer_left"))
	assert_true(st.has("seagull_pos"))
	assert_eq(typeof(st["spawn_timer_left"]), TYPE_INT)
	assert_eq(typeof(st["return_timer_left"]), TYPE_INT)
	assert_eq(typeof(st["roam_timer_left"]), TYPE_INT)


func test_get_debug_actions_returns_four_actions() -> void:
	var acts = manager.get_debug_actions()
	assert_eq(acts.size(), 4)
	var ids = []
	for act in acts:
		ids.append(act["id"])
	assert_true(ids.has("force_spawn"))
	assert_true(ids.has("skip_roam"))
	assert_true(ids.has("force_retreat"))
	assert_true(ids.has("reset_inactive"))


func test_get_debug_actions_labels() -> void:
	var acts = manager.get_debug_actions()
	var labels = {}
	for act in acts:
		labels[act["id"]] = act["label"]
	assert_eq(labels.get("force_spawn"), "Force Spawn")
	assert_eq(labels.get("skip_roam"), "Skip Roam -> Approach")
	assert_eq(labels.get("force_retreat"), "Force Retreat")
	assert_eq(labels.get("reset_inactive"), "Reset Inactive")


func test_debug_actions_execution() -> void:
	manager.debug_action("force_spawn")
	assert_eq(manager.current_state, manager.State.ROAMING, "force_spawn should set state to ROAMING")
	assert_true(is_instance_valid(manager.seagull_node))

	manager.debug_action("skip_roam")
	assert_eq(manager.current_state, manager.State.APPROACHING, "skip_roam should advance to APPROACHING")

	manager.debug_action("force_retreat")
	assert_eq(manager.current_state, manager.State.RETREATING, "force_retreat should set state to RETREATING")

	manager.debug_action("reset_inactive")
	assert_eq(manager.current_state, manager.State.INACTIVE, "reset_inactive should set state to INACTIVE")


func test_debug_action_client_noop() -> void:
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", 1)
	manager.multiplayer.multiplayer_peer = peer
	manager.current_state = manager.State.INACTIVE
	manager.debug_action("force_spawn")
	assert_eq(manager.current_state, manager.State.INACTIVE, "Client should no-op debug_action")
	manager.multiplayer.multiplayer_peer = null


func test_debug_action_honors_fishing_active_gate() -> void:
	var script = GDScript.new()
	script.source_code = "extends Node3D\nvar fishing_active: bool = false\n"
	script.reload()
	var rm = Node3D.new()
	rm.set_script(script)
	rm.name = "RoundManager"
	_parent.add_child(autofree(rm))
	manager._round_manager = rm
	manager.current_state = manager.State.INACTIVE
	manager.debug_action("force_spawn")
	assert_eq(manager.current_state, manager.State.INACTIVE, "force_spawn should honor fishing_active=false")


func test_debug_action_honors_quota_gate() -> void:
	var quota = autofree(load("res://systems/quota/quota_manager.tscn").instantiate())
	quota.name = "QuotaManager"
	_parent.add_child(quota)
	quota.shared_quota = 0
	manager.current_state = manager.State.INACTIVE
	manager.debug_action("force_spawn")
	assert_eq(manager.current_state, manager.State.WAITING, "force_spawn with zero quota should go to WAITING")


func test_seagull_manager_registers_with_debug_overlay() -> void:
	var dbg = get_node_or_null("/root/DebugOverlay")
	assert_not_null(dbg, "DebugOverlay autoload missing")
	assert_true(dbg._systems.has("SeagullManager"), "SeagullManager should register with DebugOverlay")
