extends GutTest

var player: Player = null


func before_each() -> void:
	player = await _build_player()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_player(node_name: String = "", parent: Node = null) -> Player:
	var player_node := CharacterBody3D.new()
	if not node_name.is_empty():
		player_node.name = node_name

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
	if parent != null:
		parent.add_child(p)
	else:
		autofree(p)
		add_child(p)
	await get_tree().process_frame
	return p


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
	player.holding_rock = true
	player._show_held_rock_remote()
	assert_false(player._rod_pivot.visible, "rod should be hidden when showing held rock")
	assert_not_null(player._held_rock_mesh, "_held_rock_mesh should exist after _show_held_rock_remote")
	player.holding_rock = false


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


func test_fall_off_island_triggers_death() -> void:
	player.global_position = Vector3(0, -5.0, 0)
	player.player_state = Player.PlayerState.ALIVE

	assert_lt(player.global_position.y, Player.FALL_DEATH_Y, "player should be below fall threshold")
	assert_eq(player.player_state, Player.PlayerState.ALIVE, "player should be ALIVE")
	assert_false(player._fell_off_island_reported, "fall flag should start false")

	player._check_fell_off_island()

	assert_true(player._fell_off_island_reported, "fall flag should be set after detection")

	var hp := player.get_node("HealthComponent") as HealthComponent
	assert_eq(hp.current_health, 0, "Falling off island should deplete health to 0")


func test_above_threshold_does_not_trigger_fall() -> void:
	player.global_position = Vector3(0, 2.0, 0)
	player.player_state = Player.PlayerState.ALIVE

	player._check_fell_off_island()

	assert_false(player._fell_off_island_reported, "fall flag should stay false above threshold")
	var hp := player.get_node("HealthComponent") as HealthComponent
	assert_eq(hp.current_health, hp.max_health, "No damage should be taken above threshold")


func test_fall_reports_only_once() -> void:
	player.global_position = Vector3(0, -5.0, 0)
	player.player_state = Player.PlayerState.ALIVE

	player._check_fell_off_island()
	var hp := player.get_node("HealthComponent") as HealthComponent
	var first_health := hp.current_health

	player._check_fell_off_island()
	assert_eq(hp.current_health, first_health, "Repeated checks should not re-apply damage")
	assert_true(player._fell_off_island_reported, "fall flag should remain set")


func test_fall_enters_spectate() -> void:
	player.global_position = Vector3(0, -5.0, 0)
	player.player_state = Player.PlayerState.ALIVE

	player._check_fell_off_island()

	assert_eq(player.player_state, Player.PlayerState.SPECTATE, "Falling off island should enter spectate")


func test_fall_drops_carried_fish() -> void:
	player.start_carrying()
	player.global_position = Vector3(0, -5.0, 0)
	player.player_state = Player.PlayerState.ALIVE

	player._check_fell_off_island()

	assert_false(player.is_carrying, "Carried fish should be dropped when falling to death")


func test_report_validates_position() -> void:
	player.report_fell_off_island(Vector3(0, -5.0, 0))
	var hp := player.get_node("HealthComponent") as HealthComponent
	assert_eq(hp.current_health, 0, "Report from below threshold should damage")

	hp.reset_to_max()
	player.report_fell_off_island(Vector3(0, 0, 0))
	assert_eq(hp.current_health, hp.max_health, "Report from above threshold should be ignored")


func test_respawn_at_spawn() -> void:
	player.spawn_index = 2
	player.velocity = Vector3(10, 5, 10)
	player._respawn_at_spawn()

	var expected_pos := player._spawn_positions()[2]
	assert_eq(player.position, expected_pos, "Player position should reset to designated spawn index")
	assert_eq(player.velocity, Vector3.ZERO, "Player velocity should zero out on respawn")


func test_fall_off_island_peer_branch_round_trip() -> void:
	var server_peer := ENetMultiplayerPeer.new()
	var client_peer := ENetMultiplayerPeer.new()
	var chosen_port := -1
	for port in [37877, 37878, 37879, 37880, 37881]:
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
	var server_copy := await _build_player("Player_%d" % client_id, server_players)
	var client_copy := await _build_player("Player_%d" % client_id, client_players)

	client_copy.player_state = Player.PlayerState.ALIVE
	client_copy._fell_off_island_reported = false
	client_copy.global_position = Vector3(0, -5.0, 0)

	client_copy._check_fell_off_island()

	var client_hp := client_copy.get_node("HealthComponent") as HealthComponent
	assert_true(client_copy._fell_off_island_reported, "client should set the fall flag")
	assert_eq(client_hp.current_health, client_hp.max_health, "client should not damage locally; the report goes to the server")

	var server_hp := server_copy.get_node("HealthComponent") as HealthComponent
	frames = 0
	while frames < 120 and server_hp.current_health > 0:
		await get_tree().process_frame
		frames += 1

	assert_eq(server_hp.current_health, 0, "server should receive the fall report and apply damage")
	assert_eq(client_hp.current_health, 0, "server should relay damage back to the owning client")
	assert_eq(client_copy.player_state, Player.PlayerState.SPECTATE, "client should enter spectate after fall death")

	server_peer.close()
	client_peer.close()
	get_tree().set_multiplayer(null, server_root.get_path())
	get_tree().set_multiplayer(null, client_root.get_path())
	server_root.queue_free()
	client_root.queue_free()


func test_sitting_starts_false() -> void:
	assert_false(player._sitting_heal.is_sitting, "Sitting should start false")


func test_sitting_blocks_movement() -> void:
	player._sitting_heal.set_sitting(true)
	player.velocity = Vector3(5, 0, 5)
	player._physics_process(0.016)
	assert_true(player._sitting_heal.is_sitting, "Player should remain sitting with no input")
	assert_eq(player.velocity.x, 0.0, "Horizontal velocity should be locked while sitting")
	assert_eq(player.velocity.z, 0.0, "Horizontal velocity should be locked while sitting")


func test_wasd_press_stands_player_up() -> void:
	player._sitting_heal.set_sitting(true)
	Input.action_press("move_right")
	player._physics_process(0.016)
	Input.action_release("move_right")
	assert_false(player._sitting_heal.is_sitting, "WASD press should stand the player up")


func test_prompt_visible_without_carrying_when_allowed() -> void:
	player.is_carrying = false
	player._ray_hit_box = true
	var interactable: InteractableComponent = autofree(InteractableComponent.new())
	interactable.show_prompt_without_carrying = true
	interactable.prompt_text = "Sit by the Fireplace [Right-click]"
	player._update_prompt_visibility(interactable)
	var label := player._interact_prompt.get_node("PromptLabel") as Label
	assert_true(label.visible, "Prompt should show without carrying when interactable allows it")
	assert_eq(label.text, "Sit by the Fireplace [Right-click]", "Prompt should show interactable text")


func test_prompt_hidden_without_carrying_when_not_allowed() -> void:
	player.is_carrying = false
	player._ray_hit_box = true
	var interactable: InteractableComponent = autofree(InteractableComponent.new())
	player._update_prompt_visibility(interactable)
	var label := player._interact_prompt.get_node("PromptLabel") as Label
	assert_false(label.visible, "Prompt should stay hidden without carrying when not allowed")


func test_restart_clears_sitting() -> void:
	player._sitting_heal.set_sitting(true)
	player.reset_for_restart()
	assert_false(player._sitting_heal.is_sitting, "Restart should stand the player up")


func test_holding_shark_bait_starts_false() -> void:
	assert_false(player.holding_shark_bait, "holding_shark_bait should start false")
	assert_null(player._held_bait_mesh, "held_bait_mesh should start null")


func test_start_holding_shark_bait_shows_mesh_and_hides_rod() -> void:
	player.start_holding_shark_bait()
	assert_true(player.holding_shark_bait, "holding_shark_bait should be true")
	assert_not_null(player._held_bait_mesh, "held_bait_mesh should exist")
	assert_false(player._rod_pivot.visible, "rod should be hidden when holding shark bait")


func test_clear_holding_shark_bait_shows_rod() -> void:
	player.start_holding_shark_bait()
	player.clear_holding_shark_bait()
	assert_false(player.holding_shark_bait, "holding_shark_bait should be false after clear")
	assert_null(player._held_bait_mesh, "held_bait_mesh should be null after clear")
	assert_true(player._rod_pivot.visible, "rod should be visible after clear")


func test_cast_blocked_while_holding_shark_bait() -> void:
	player.holding_shark_bait = true
	var snapshot_state = player.fishing_mechanic.current_state
	var ev := InputEventAction.new()
	ev.action = "cast_line"
	ev.pressed = true
	player._unhandled_input(ev)
	assert_eq(player.fishing_mechanic.current_state, snapshot_state, "casting action should not change fishing state while holding shark bait")
	player.holding_shark_bait = false


func test_pickup_rock_blocked_while_holding_shark_bait() -> void:
	player.holding_shark_bait = true
	assert_false(player._try_pickup_rock(), "pickup rock should be blocked while holding shark bait")
	player.holding_shark_bait = false


func test_reset_for_restart_clears_holding_shark_bait() -> void:
	player.start_holding_shark_bait()
	player.reset_for_restart()
	assert_false(player.holding_shark_bait, "holding_shark_bait should be false after restart")
	assert_null(player._held_bait_mesh, "held_bait_mesh should be null after restart")
	assert_true(player._rod_pivot.visible, "rod should be visible after restart")


func test_damage_clears_holding_shark_bait() -> void:
	player.start_holding_shark_bait()
	var hp := player.get_node("HealthComponent") as HealthComponent
	hp.take_damage(1)
	assert_false(player.holding_shark_bait, "taking damage should clear holding shark bait")
	assert_null(player._held_bait_mesh, "held_bait_mesh should be null after damage")


func test_water_surface_enters_floating() -> void:
	player.global_position = Vector3(0, -1.0, 0)
	player.player_state = Player.PlayerState.ALIVE

	assert_eq(player.player_state, Player.PlayerState.ALIVE, "player should start ALIVE")
	player._check_fell_off_island()

	assert_eq(player.player_state, Player.PlayerState.FLOATING, "Crossing water surface should enter FLOATING state")
	var hp := player.get_node("HealthComponent") as HealthComponent
	assert_eq(hp.current_health, hp.max_health, "Water surface entry should not deplete health")


func test_entering_floating_drops_carried_fish_and_rock() -> void:
	player.start_carrying()
	player.holding_rock = true
	player.global_position = Vector3(0, -1.0, 0)
	player.player_state = Player.PlayerState.ALIVE

	player._check_fell_off_island()

	assert_eq(player.player_state, Player.PlayerState.FLOATING)
	assert_false(player.is_carrying, "Carried fish should be dropped on entering floating")
	assert_false(player.holding_rock, "Held rock should be dropped on entering floating")


func test_reset_for_restart_resets_floating_state() -> void:
	player.global_position = Vector3(0, -1.0, 0)
	player.player_state = Player.PlayerState.FLOATING

	player.reset_for_restart()

	assert_eq(player.player_state, Player.PlayerState.ALIVE, "Restart should reset player from FLOATING to ALIVE")

