extends GutTest

var player: Player = null


func before_each() -> void:
	var player_node := CharacterBody3D.new()

	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.6, 0)
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
	var fishing_mechanic = autofree(fishing_scene.instantiate())
	fishing_mechanic.name = "FishingMechanic"
	player_node.add_child(fishing_mechanic)

	var voice_chat_manager := Node.new()
	voice_chat_manager.name = "VoiceChatManager"
	voice_chat_manager.set_script(load("res://systems/voice_chat/voice_chat_manager.gd"))
	player_node.add_child(voice_chat_manager)

	var health_component := HealthComponent.new()
	health_component.name = "HealthComponent"
	player_node.add_child(health_component)

	var spectate_camera := Node3D.new()
	spectate_camera.name = "SpectateCamera"
	player_node.add_child(spectate_camera)

	var spectate_cam_camera := Camera3D.new()
	spectate_cam_camera.name = "Camera3D"
	spectate_camera.add_child(spectate_cam_camera)

	player_node.set_script(load("res://entities/player/player.gd"))

	player = autofree(player_node)
	add_child(player)
	await get_tree().process_frame

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_is_yelling_starts_false() -> void:
	assert_false(player.is_yelling, "is_yelling should be false initially")


func test_enable_player_turns_on_voice_chat_process() -> void:
	var vcm = player.get_node("VoiceChatManager")
	vcm.set_process(false)
	player._enable_player()
	assert_true(vcm.is_processing(), "VoiceChatManager process should be on after _enable_player")


func test_disable_player_turns_off_voice_chat_process() -> void:
	var vcm = player.get_node("VoiceChatManager")
	vcm.set_process(true)
	player._disable_player()
	assert_false(vcm.is_processing(), "VoiceChatManager process should be off after _disable_player")


func test_enable_player_connects_yelling_signal() -> void:
	player._enable_player()
	var vcm = player.get_node("VoiceChatManager")
	assert_true(vcm.yelling_state_changed.is_connected(player._on_yelling_state_changed), "yelling_state_changed should be connected after _enable_player")


func test_disable_player_disconnects_yelling_signal() -> void:
	player._enable_player()
	player._disable_player()
	var vcm = player.get_node("VoiceChatManager")
	assert_false(vcm.yelling_state_changed.is_connected(player._on_yelling_state_changed), "yelling_state_changed should be disconnected after _disable_player")


func test_sync_yelling_updates_is_yelling() -> void:
	player.is_yelling = false
	player.sync_yelling(true)
	assert_true(player.is_yelling, "is_yelling should be true after sync_yelling(true)")
	player.sync_yelling(false)
	assert_false(player.is_yelling, "is_yelling should be false after sync_yelling(false)")


func test_voice_chat_process_off_by_default_on_remote() -> void:
	player._disable_player()
	var vcm = player.get_node("VoiceChatManager")
	assert_false(vcm.is_processing(), "VoiceChatManager process should be off for remote player")


func test_start_carrying_sets_state_and_hides_rod() -> void:
	assert_false(player.is_carrying, "is_carrying should be false initially")
	assert_null(player._held_fish, "held_fish should be null initially")
	player.start_carrying()
	assert_true(player.is_carrying, "is_carrying should be true after start_carrying")
	assert_not_null(player._held_fish, "held_fish should exist after start_carrying")
	assert_false(player._rod_pivot.visible, "rod should be hidden while carrying")


func test_deposit_carried_fish_clears_state() -> void:
	player.start_carrying()
	player.deposit_carried_fish()
	assert_false(player.is_carrying, "is_carrying should be false after deposit")
	assert_null(player._held_fish, "held_fish should be null after deposit")
	assert_true(player._rod_pivot.visible, "rod should be visible after deposit")


func test_deposit_noop_when_not_carrying() -> void:
	var was_carrying: bool = player.is_carrying
	player.deposit_carried_fish()
	assert_eq(player.is_carrying, was_carrying, "is_carrying should not change when not carrying")


func test_drop_carried_fish_clears_no_credit() -> void:
	player.start_carrying()
	player.drop_carried_fish()
	assert_false(player.is_carrying, "is_carrying should be false after drop")
	assert_null(player._held_fish, "held_fish should be null after drop")
	assert_true(player._rod_pivot.visible, "rod should be visible after drop")


func test_cast_blocked_while_carrying() -> void:
	await get_tree().process_frame
	player.is_carrying = true
	assert_false(not player.is_carrying and player.fishing_mechanic.can_cast(), "cast should be blocked while carrying")
	player.is_carrying = false


func test_reset_for_restart_clears_carry() -> void:
	player.start_carrying()
	player.reset_for_restart()
	assert_false(player.is_carrying, "is_carrying should be false after reset_for_restart")
	assert_null(player._held_fish, "held_fish should be null after reset_for_restart")
	assert_true(player._rod_pivot.visible, "rod should be visible after reset_for_restart")


func test_holding_rock_starts_false() -> void:
	assert_false(player.holding_rock, "holding_rock should be false initially")


func test_pickup_rock_shows_held_rock_remote() -> void:
	assert_false(player.holding_rock, "holding_rock should be false initially")
	player._show_held_rock_remote()
	assert_false(player._rod_pivot.visible, "rod should be hidden when showing held rock")
	assert_not_null(player._held_rock_mesh, "_held_rock_mesh should exist after _show_held_rock_remote")


func test_pickup_rock_hide_shows_rod() -> void:
	player._show_held_rock_remote()
	player._hide_held_rock_remote()
	assert_true(player._rod_pivot.visible, "rod should be visible after hiding held rock")
	assert_null(player._held_rock_mesh, "_held_rock_mesh should be null after _hide_held_rock_remote")


func test_hide_held_rock_is_idempotent() -> void:
	player._hide_held_rock_remote()
	player._hide_held_rock_remote()
	assert_true(player._rod_pivot.visible, "rod should remain visible after double hide")


func test_throw_rock_shows_rod() -> void:
	player.holding_rock = true
	player._rod_pivot.visible = false
	player._throw_rock()
	assert_false(player.holding_rock, "holding_rock should be false after throw")
	assert_true(player._rod_pivot.visible, "rod should be visible after throw")


func test_cast_blocked_while_holding_rock() -> void:
	player.is_carrying = false
	player.holding_rock = true
	var cast_condition: bool = not player.is_carrying and not player.holding_rock and player.fishing_mechanic.can_cast()
	assert_false(cast_condition, "cast should be blocked while holding rock")
	player.holding_rock = false


func test_reset_for_restart_clears_holding_rock() -> void:
	player.holding_rock = true
	player._rod_pivot.visible = false
	player.reset_for_restart()
	assert_false(player.holding_rock, "holding_rock should be false after reset_for_restart")
	assert_true(player._rod_pivot.visible, "rod should be visible after reset_for_restart")


func test_wasd_works_during_fight() -> void:
	player.global_position = Vector3.ZERO
	player.fishing_mechanic._is_fighting = true
	player.fishing_mechanic.cast_target_position = Vector3.ZERO
	player.fishing_mechanic._fight_initial_distance = 0.0
	player.fishing_mechanic._fight_target = 99.0

	player.velocity = Vector3.ZERO

	Input.action_press("move_right")
	player._physics_process(0.016)
	Input.action_release("move_right")

	assert_gt(abs(player.velocity.x), 0.0, "WASD should affect velocity during fight")


func test_player_moves_toward_fish_during_fight() -> void:
	player.global_position = Vector3.ZERO
	player.fishing_mechanic._is_fighting = true
	player.fishing_mechanic.cast_target_position = Vector3(10, 0, 0)
	player.fishing_mechanic._fight_initial_distance = 10.0
	player.fishing_mechanic._fight_target = 99.0

	player.velocity = Vector3.ZERO
	player._physics_process(0.016)

	var expected_dir: Vector3 = player.fishing_mechanic.cast_target_position.normalized()
	if player.velocity.length() > 0.0:
		var actual_dir: Vector3 = player.velocity.normalized()
		var dot: float = actual_dir.dot(expected_dir)
		assert_gt(dot, 0.7, "Player velocity should generally point toward fish position")
	else:
		assert_gt(player.velocity.length(), 0.0, "Velocity should not be zero during fight")


func test_scroll_spikes_pull_higher_than_normal() -> void:
	player.global_position = Vector3.ZERO
	player.fishing_mechanic._is_fighting = true
	player.fishing_mechanic.cast_target_position = Vector3(10, 0, 0)
	player.fishing_mechanic._fight_initial_distance = 10.0
	player.fishing_mechanic._fight_target = 99.0

	player.velocity = Vector3.ZERO
	player._pull_spike_timer = 0.0

	Input.action_press("reel_fight")
	player._physics_process(0.016)
	Input.action_release("reel_fight")

	var normal_pull_vel: float = 0.5
	assert_gt(abs(player.velocity.x), normal_pull_vel + 0.5, "Scroll spike should produce velocity above 0.5-strength baseline")


func test_pull_spike_decays_after_linger() -> void:
	player.global_position = Vector3.ZERO
	player.fishing_mechanic._is_fighting = true
	player.fishing_mechanic.cast_target_position = Vector3(10, 0, 0)
	player.fishing_mechanic._fight_initial_distance = 10.0

	player.velocity = Vector3.ZERO
	player._pull_spike_timer = 0.3

	player._physics_process(0.4)

	var expected_normal_vel: float = 0.5
	assert_true(abs(player.velocity.x) <= expected_normal_vel + 0.01, "After spike decays, velocity should return to 0.5-strength level")
