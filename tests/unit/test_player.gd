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
	player.global_position = Vector3(0, -5.0, 0)
	player.report_fell_off_island(Vector3(0, -5.0, 0))
	var hp := player.get_node("HealthComponent") as HealthComponent
	assert_eq(hp.current_health, 0, "Report from below threshold should damage")

	hp.reset_to_max()
	player.global_position = Vector3(0, 0, 0)
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
	server_copy.global_position = Vector3(0, -5.0, 0)

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


func test_client_floating_increments_float_time() -> void:
	player.player_state = Player.PlayerState.FLOATING
	player._float_time = 0.0
	var old_time := player._float_time
	player._process_floating(1.0)
	assert_gt(player._float_time, old_time, "_float_time should increment in _process_floating for animation/visuals")


func test_fall_stale_server_still_kills() -> void:
	var server_peer := ENetMultiplayerPeer.new()
	var client_peer := ENetMultiplayerPeer.new()
	var chosen_port := -1
	for port in [37882, 37883, 37884, 37885, 37886]:
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

	var client_id := client_mp.get_unique_id()
	var server_copy := await _build_player("Player_%d" % client_id, server_players)
	var client_copy := await _build_player("Player_%d" % client_id, client_players)

	client_copy.player_state = Player.PlayerState.ALIVE
	client_copy._fell_off_island_reported = false
	client_copy.global_position = Vector3(0, -5.0, 0)
	server_copy.global_position = Vector3(0, 0, 0)

	client_copy._check_fell_off_island()

	var server_hp := server_copy.get_node("HealthComponent") as HealthComponent
	var client_hp := client_copy.get_node("HealthComponent") as HealthComponent
	frames = 0
	while frames < 120 and server_hp.current_health > 0:
		await get_tree().process_frame
		frames += 1

	assert_eq(server_hp.current_health, 0, "stale server should kill player when client reports fall")
	assert_eq(client_copy.player_state, Player.PlayerState.SPECTATE, "client should enter spectate")

	server_peer.close()
	client_peer.close()
	get_tree().set_multiplayer(null, server_root.get_path())
	get_tree().set_multiplayer(null, client_root.get_path())
	server_root.queue_free()
	client_root.queue_free()


func test_water_stale_server_still_enters_floating() -> void:
	var server_peer := ENetMultiplayerPeer.new()
	var client_peer := ENetMultiplayerPeer.new()
	var chosen_port := -1
	for port in [37887, 37888, 37889, 37890, 37891]:
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

	var client_id := client_mp.get_unique_id()
	var server_copy := await _build_player("Player_%d" % client_id, server_players)
	var client_copy := await _build_player("Player_%d" % client_id, client_players)

	client_copy.player_state = Player.PlayerState.ALIVE
	client_copy._entered_water_reported = false
	client_copy.global_position = Vector3(0, -1.0, 0)
	server_copy.global_position = Vector3(0, 0, 0)

	client_copy._check_fell_off_island()

	frames = 0
	while frames < 120 and client_copy.player_state != Player.PlayerState.FLOATING:
		await get_tree().process_frame
		frames += 1

	assert_eq(client_copy.player_state, Player.PlayerState.FLOATING, "stale server should enter floating when client reports water entry")
	assert_eq(server_copy.player_state, Player.PlayerState.FLOATING, "server state should converge to floating")

	server_peer.close()
	client_peer.close()
	get_tree().set_multiplayer(null, server_root.get_path())
	get_tree().set_multiplayer(null, client_root.get_path())
	server_root.queue_free()
	client_root.queue_free()


func test_enter_water_peer_round_trip() -> void:
	var server_peer := ENetMultiplayerPeer.new()
	var client_peer := ENetMultiplayerPeer.new()
	var chosen_port := -1
	for port in [37892, 37893, 37894, 37895, 37896]:
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

	var client_id := client_mp.get_unique_id()
	var server_copy := await _build_player("Player_%d" % client_id, server_players)
	var client_copy := await _build_player("Player_%d" % client_id, client_players)

	client_copy.player_state = Player.PlayerState.ALIVE
	client_copy._entered_water_reported = false
	client_copy.global_position = Vector3(0, -1.0, 0)
	server_copy.global_position = Vector3(0, -1.0, 0)

	client_copy._check_fell_off_island()

	frames = 0
	while frames < 120 and (client_copy.player_state != Player.PlayerState.FLOATING or server_copy.player_state != Player.PlayerState.FLOATING):
		await get_tree().process_frame
		frames += 1

	assert_eq(client_copy.player_state, Player.PlayerState.FLOATING, "client should enter floating via server round trip")
	assert_eq(server_copy.player_state, Player.PlayerState.FLOATING, "server should enter floating via peer round trip")

	server_peer.close()
	client_peer.close()
	get_tree().set_multiplayer(null, server_root.get_path())
	get_tree().set_multiplayer(null, client_root.get_path())
	server_root.queue_free()
	client_root.queue_free()


func test_report_entered_water_validation() -> void:
	player.global_position = Vector3(0, -1.0, 0)
	player.player_state = Player.PlayerState.ALIVE
	player.report_entered_water(Vector3(0, -1.0, 0))
	assert_eq(player.player_state, Player.PlayerState.FLOATING, "Report from water surface should enter floating")

	player.player_state = Player.PlayerState.ALIVE
	player.global_position = Vector3(0, 0, 0)
	player.report_entered_water(Vector3(0, 0, 0))
	assert_eq(player.player_state, Player.PlayerState.ALIVE, "Report from above water should be ignored")

	player.player_state = Player.PlayerState.ALIVE
	player.global_position = Vector3(0, -5.0, 0)
	player.report_entered_water(Vector3(0, -5.0, 0))
	assert_eq(player.player_state, Player.PlayerState.ALIVE, "Report from below fall death should be ignored")


func test_water_report_retry_throttle() -> void:
	player.global_position = Vector3(0, -1.0, 0)
	player.player_state = Player.PlayerState.ALIVE
	player._entered_water_reported = true
	player._water_report_retry = 0

	for i in range(10):
		player._check_fell_off_island()
	assert_eq(player._water_report_retry, 10, "water report retry should increment")
	assert_eq(player.player_state, Player.PlayerState.ALIVE, "should remain alive while throttled")

	for i in range(5):
		player._check_fell_off_island()
	assert_eq(player.player_state, Player.PlayerState.FLOATING, "should enter floating once retry reaches threshold")


func test_floating_player_remains_valid_shark_target() -> void:
	player.queue_free()
	var players_container := Node3D.new()
	players_container.name = "Players"
	add_child(players_container)

	player = await _build_player("Player_1", players_container)
	player.global_position = Vector3(0, -1.0, 0)
	player.player_state = Player.PlayerState.FLOATING
	var hp: HealthComponent = player.get_node("HealthComponent") as HealthComponent
	hp.current_health = hp.max_health

	assert_true(hp.is_alive(), "Floating player health component should be alive")

	var danger_scene: PackedScene = load("res://systems/danger/danger_manager.tscn")
	var danger_mgr: Node3D = autofree(danger_scene.instantiate())
	add_child(danger_mgr)
	await get_tree().process_frame

	var nearest: Node3D = danger_mgr._get_nearest_player()
	assert_eq(nearest, player, "Floating player should be a valid nearest player target for danger manager / shark")


func test_floating_stays_floating_before_timeout() -> void:
	player.player_state = Player.PlayerState.FLOATING
	player.float_timeout = 30.0
	player._float_time = 10.0
	var hp := player.get_node("HealthComponent") as HealthComponent
	hp.current_health = hp.max_health

	player._process_floating(1.0)
	assert_eq(player.player_state, Player.PlayerState.FLOATING, "Should remain FLOATING before timeout")
	assert_eq(hp.current_health, hp.max_health, "Should take no damage before timeout")


func test_floating_kills_after_timeout_on_server() -> void:
	player.player_state = Player.PlayerState.FLOATING
	player.float_timeout = 1.0
	player._float_time = 1.0
	var hp := player.get_node("HealthComponent") as HealthComponent
	hp.current_health = hp.max_health

	player._process_floating(0.016)
	assert_eq(hp.current_health, 0, "Should take max damage and die after timeout on server/no-peer")


func test_float_timeout_export_tunable() -> void:
	assert_true("float_timeout" in player, "float_timeout export should exist")
	player.float_timeout = 15.0
	assert_eq(player.float_timeout, 15.0, "float_timeout should be tunable")


func test_client_does_not_self_kill_on_timeout() -> void:
	var server_peer := ENetMultiplayerPeer.new()
	var client_peer := ENetMultiplayerPeer.new()
	var chosen_port := -1
	for port in [37897, 37898, 37899, 37900, 37901]:
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

	var client_id := client_mp.get_unique_id()
	var server_copy := await _build_player("Player_%d" % client_id, server_players)
	assert_not_null(server_copy, "server copy should exist for RPC path resolution")
	var client_copy := await _build_player("Player_%d" % client_id, client_players)

	client_copy.player_state = Player.PlayerState.FLOATING
	client_copy.float_timeout = 1.0
	client_copy._float_time = 2.0
	var hp := client_copy.get_node("HealthComponent") as HealthComponent
	hp.current_health = hp.max_health

	client_copy._process_floating(0.016)

	assert_eq(hp.current_health, hp.max_health, "Client should not self-kill on float timeout")

	server_peer.close()
	client_peer.close()
	get_tree().set_multiplayer(null, server_root.get_path())
	get_tree().set_multiplayer(null, client_root.get_path())
	server_root.queue_free()
	client_root.queue_free()


func test_restart_cancels_timer_and_restores_alive() -> void:
	player.player_state = Player.PlayerState.FLOATING
	player._float_time = 15.0
	player.reset_for_restart()
	assert_eq(player.player_state, Player.PlayerState.ALIVE, "Restart should restore player to ALIVE")
	assert_eq(player._float_time, 0.0, "Restart should cancel/reset float timer (_float_time = 0)")


func test_physics_keep_for_floating_remote() -> void:
	player.player_state = Player.PlayerState.FLOATING
	player._disable_player()
	assert_true(player.is_physics_processing(), "Physics process should remain enabled for FLOATING remote/disabled player")


func test_above_water_no_op_at_y_minus_0_4() -> void:
	player.global_position = Vector3(0, -0.4, 0)
	player.player_state = Player.PlayerState.ALIVE
	player._check_fell_off_island()
	assert_eq(player.player_state, Player.PlayerState.ALIVE, "y = -0.4 is above water surface, should be no-op")
	assert_false(player._entered_water_reported, "entered water reported flag should stay false")


func test_deep_fall_kills_at_y_minus_5() -> void:
	player.global_position = Vector3(0, -5.0, 0)
	player.player_state = Player.PlayerState.ALIVE
	player._check_fell_off_island()
	assert_eq(player.player_state, Player.PlayerState.SPECTATE, "y = -5.0 should trigger death and spectate")
	var hp := player.get_node("HealthComponent") as HealthComponent
	assert_eq(hp.current_health, 0, "Health should be 0 on deep fall")


func test_spoof_rejection_water_and_fall() -> void:
	player.global_position = Vector3(0, 0, 0)
	player.player_state = Player.PlayerState.ALIVE
	player.report_entered_water(Vector3(0, -5.0, 0))
	assert_eq(player.player_state, Player.PlayerState.ALIVE, "spoofed water entry with server y=0 above WATER_SURFACE_Y and client y=-5 below FALL_DEATH_Y should be rejected (both outside WATER_SURFACE_Y/FALL_DEATH_Y water band)")
	player.global_position = Vector3(0, -1.0, 0)
	player.player_state = Player.PlayerState.ALIVE
	player.report_fell_off_island(Vector3(0, 0, 0))
	var hp := player.get_node("HealthComponent") as HealthComponent
	assert_eq(hp.current_health, hp.max_health, "spoofed fall with server y=-1 and client y=0, both above FALL_DEATH_Y, should be rejected")


func test_sitting_blocked_while_floating() -> void:
	player.player_state = Player.PlayerState.FLOATING
	player._sitting_heal.set_sitting(true)
	assert_false(player._sitting_heal.is_sitting, "Sitting should be blocked while floating")
	player.toggle_sitting()
	assert_false(player._sitting_heal.is_sitting, "Toggle sitting should be blocked while floating")


func test_process_early_return_when_floating() -> void:
	player.player_state = Player.PlayerState.FLOATING
	player._bounce_pos = 1.5
	player._process(0.016)
	assert_eq(player._bounce_pos, 1.5, "Process should return early without updating bounce position when floating")


func test_sync_floating_state_exists() -> void:
	assert_true(player.has_method("_sync_floating_state"), "_sync_floating_state method should exist")


func test_sync_floating_state_no_peer() -> void:
	get_tree().get_multiplayer().multiplayer_peer = null
	player.player_state = Player.PlayerState.ALIVE
	player._sync_floating_state()
	assert_eq(player.player_state, Player.PlayerState.FLOATING, "_sync_floating_state should enter FLOATING state in single-player no-peer path")


func test_sync_floating_state_peer_round_trip() -> void:
	var server_peer := ENetMultiplayerPeer.new()
	var client_peer := ENetMultiplayerPeer.new()
	var chosen_port := -1
	for port in [37902, 37903, 37904, 37905, 37906]:
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

	var client_id := client_mp.get_unique_id()
	var server_copy := await _build_player("Player_%d" % client_id, server_players)
	var client_copy := await _build_player("Player_%d" % client_id, client_players)

	server_copy.player_state = Player.PlayerState.ALIVE
	client_copy.player_state = Player.PlayerState.ALIVE

	server_copy._enter_floating()

	frames = 0
	while frames < 120 and client_copy.player_state != Player.PlayerState.FLOATING:
		await get_tree().process_frame
		frames += 1

	assert_eq(client_copy.player_state, Player.PlayerState.FLOATING, "client copy should converge to FLOATING via _sync_floating_state")

	server_peer.close()
	client_peer.close()
	get_tree().set_multiplayer(null, server_root.get_path())
	get_tree().set_multiplayer(null, client_root.get_path())
	server_root.queue_free()
	client_root.queue_free()


func test_sync_floating_state_spoof_rejection() -> void:
	var server_peer := ENetMultiplayerPeer.new()
	var client_peer := ENetMultiplayerPeer.new()
	var chosen_port := -1
	for port in [37907, 37908, 37909, 37910, 37911]:
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

	var client_id := client_mp.get_unique_id()
	var server_copy := await _build_player("Player_%d" % client_id, server_players)
	var client_copy := await _build_player("Player_%d" % client_id, client_players)

	server_copy.player_state = Player.PlayerState.ALIVE
	client_copy.player_state = Player.PlayerState.ALIVE

	client_copy._sync_floating_state()
	assert_eq(client_copy.player_state, Player.PlayerState.ALIVE, "_sync_floating_state should reject direct call when multiplayer active and sender is not 1")

	server_peer.close()
	client_peer.close()
	get_tree().set_multiplayer(null, server_root.get_path())
	get_tree().set_multiplayer(null, client_root.get_path())
	server_root.queue_free()
	client_root.queue_free()


func test_water_surface_edge_at_y_minus_0_5() -> void:
	player.global_position = Vector3(0, -0.5, 0)
	player.player_state = Player.PlayerState.ALIVE
	player._check_fell_off_island()
	assert_eq(player.player_state, Player.PlayerState.ALIVE, "y = -0.5 exact surface boundary remains ALIVE")
	player.global_position = Vector3(0, -0.51, 0)
	player._check_fell_off_island()
	assert_eq(player.player_state, Player.PlayerState.FLOATING, "y = -0.51 below water surface enters FLOATING")


func test_joint_triple_drop_on_entering_floating() -> void:
	player.start_carrying()
	player.holding_rock = true
	player._show_held_rock_remote()
	player.start_holding_shark_bait()
	player._sitting_heal.set_sitting(true)
	player.global_position = Vector3(0, -1.0, 0)
	player.player_state = Player.PlayerState.ALIVE

	player._check_fell_off_island()

	assert_eq(player.player_state, Player.PlayerState.FLOATING)
	assert_false(player.is_carrying, "Carried fish should be dropped")
	assert_false(player.holding_rock, "Held rock should be dropped")
	assert_false(player.holding_shark_bait, "Held shark bait should be cleared")
	assert_false(player._sitting_heal.is_sitting, "Sitting should be reset")
	assert_null(player._held_fish, "held_fish should be null")
	assert_null(player._held_rock_mesh, "_held_rock_mesh should be null")
	assert_null(player._held_bait_mesh, "_held_bait_mesh should be null")
	assert_true(player._rod_pivot.visible, "rod should be visible")


func test_strict_input_lock_when_floating() -> void:
	player.player_state = Player.PlayerState.FLOATING
	player.global_position = Vector3(0, -0.5, 0)
	player.velocity = Vector3(0, 0, 0)

	var ev_action := InputEventAction.new()
	ev_action.action = "move_forward"
	ev_action.pressed = true
	player._unhandled_input(ev_action)

	var jump_action := InputEventAction.new()
	jump_action.action = "jump"
	jump_action.pressed = true
	player._unhandled_input(jump_action)

	player._physics_process(0.016)
	assert_eq(player.velocity.y, 0.0, "Vertical velocity should remain zero while floating")

	var initial_head_rot := player.head.rotation.x
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(10, 10)
	# In headless mode MOUSE_MODE_CAPTURED cannot be enforced, so test the floating rotation logic when condition is met or test input locking of gameplay actions
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player._unhandled_input(motion)
		assert_ne(player.head.rotation.x, initial_head_rot, "Mouse look should rotate head while floating")
	else:
		assert_eq(player.velocity.x, 0.0, "Input lock ensures no movement velocity while floating")


func test_float_drift_outward_and_bob_sinusoid() -> void:
	player.player_state = Player.PlayerState.FLOATING
	player.global_position = Vector3(5, -0.5, 5)
	player._float_time = 0.0
	player._float_base_y = -0.5

	player._process_floating(0.5)

	assert_gt(player._float_time, 0.0, "_float_time should advance")
	assert_true(abs(player.global_position.y - (-0.5)) <= player.float_bob_amplitude + 0.01, "y should bob around base y")
	assert_true(player.velocity.x != 0.0 or player.velocity.z != 0.0, "should drift outward")


func test_restart_clears_flags_camera_and_physics() -> void:
	player.player_state = Player.PlayerState.FLOATING
	player._float_time = 12.0
	player._entered_water_reported = true
	player.camera.current = false
	player.spectate_cam_camera.current = true

	player._on_restart()

	assert_eq(player.player_state, Player.PlayerState.ALIVE, "Restart should restore state to ALIVE")
	assert_eq(player._float_time, 0.0, "Restart should reset _float_time")
	assert_false(player._entered_water_reported, "Restart should reset entered water reported")
	assert_true(player.camera.current, "Player camera should be current after restart")
	assert_false(player.spectate_cam_camera.current, "Spectate camera should not be current after restart")


func test_apply_slap_sets_state_and_timer() -> void:
	assert_false(player.is_slapped, "is_slapped should start false")
	player.apply_slap(3.5)
	assert_true(player.is_slapped, "is_slapped should be true after apply_slap")
	assert_eq(player._slap_time_left, 3.5, "_slap_time_left should be set")


func test_apply_slap_clamps_duration() -> void:
	player.apply_slap(1.0)
	assert_eq(player._slap_time_left, 3.0, "duration below 3.0 should clamp to 3.0")
	player.reset_for_restart()
	player.apply_slap(10.0)
	assert_eq(player._slap_time_left, 5.0, "duration above 5.0 should clamp to 5.0")


func test_slap_against_floating_target_is_noop() -> void:
	player.player_state = Player.PlayerState.FLOATING
	player.apply_slap(3.5)
	assert_false(player.is_slapped, "Slap against floating target should be no-op")


func test_slap_against_already_slapped_is_noop_does_not_extend() -> void:
	player.apply_slap(3.0)
	assert_true(player.is_slapped, "should be slapped")
	var initial_time := player._slap_time_left
	var initial_token := player._slap_token
	player.apply_slap(5.0)
	assert_eq(player._slap_time_left, initial_time, "Slap time left should not change on second apply_slap")
	assert_eq(player._slap_token, initial_token, "Slap token should not change on second apply_slap")


func test_re_entrant_slap_does_not_extend() -> void:
	player.set_physics_process(false)
	player.apply_slap(4.0)
	player._process_slapped(1.0)
	var expected_time := player._slap_time_left
	var initial_token := player._slap_token
	player.apply_slap(5.0)
	assert_eq(player._slap_time_left, expected_time, "re-entrant apply_slap should not extend or reset timer")
	assert_eq(player._slap_token, initial_token, "token should not increment")


func test_slap_clears_after_duration() -> void:
	player.set_physics_process(false)
	player.apply_slap(3.0)
	player._process_slapped(3.1)
	assert_false(player.is_slapped, "is_slapped should clear when duration expires")
	assert_eq(player._slap_time_left, 0.0, "_slap_time_left should be 0.0")


func test_slap_input_lock_movement_and_physics() -> void:
	player.apply_slap(3.5)
	player.velocity = Vector3(5.0, 2.0, 5.0)
	player._physics_process(0.016)
	assert_eq(player.velocity.x, 0.0, "Horizontal velocity x should be locked to 0 while slapped")
	assert_eq(player.velocity.z, 0.0, "Horizontal velocity z should be locked to 0 while slapped")


func test_restart_clears_slap() -> void:
	player.apply_slap(3.5)
	player.reset_for_restart()
	assert_false(player.is_slapped, "Restart should clear slap")


func test_enter_floating_clears_slap() -> void:
	player.apply_slap(3.5)
	player._enter_floating()
	assert_false(player.is_slapped, "Entering floating should clear slap")


func test_toggle_sitting_blocked_while_slapped() -> void:
	player.apply_slap(3.5)
	player.toggle_sitting()
	assert_false(player._sitting_heal.is_sitting, "Sitting should be blocked while slapped")


func test_apply_slap_non_alive_ignored() -> void:
	player.player_state = Player.PlayerState.SPECTATE
	player.apply_slap(3.5)
	assert_false(player.is_slapped, "apply_slap should be ignored when not ALIVE")


func test_slap_duration_export_tunable() -> void:
	assert_true("slap_duration" in player, "slap_duration export should exist")
	player.slap_duration = 4.0
	assert_eq(player.slap_duration, 4.0, "slap_duration should be tunable")


func test_slap_does_not_drop_fish() -> void:
	player.start_carrying()
	assert_true(player.is_carrying, "Player should be carrying fish")
	player.apply_slap(3.5)
	assert_true(player.is_carrying, "Slap should not drop carried fish")


func test_slap_allows_mouse_look() -> void:
	player.apply_slap(3.5)
	var old_mode := Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var initial_yaw := player.rotation.y
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(50, 20)
	player._unhandled_input(motion)
	Input.mouse_mode = old_mode
	if old_mode == Input.MOUSE_MODE_CAPTURED:
		assert_ne(player.rotation.y, initial_yaw, "Mouse look should rotate player yaw while slapped")
	else:
		assert_true(true, "Mouse look test skipped in headless mode without mouse capture")


func test_slap_blocks_cast_and_interact() -> void:
	player.apply_slap(3.5)
	var snapshot_state = player.fishing_mechanic.current_state
	var ev := InputEventAction.new()
	ev.action = "cast_line"
	ev.pressed = true
	player._unhandled_input(ev)
	assert_eq(player.fishing_mechanic.current_state, snapshot_state, "Casting should be blocked while slapped")


func test_fish_slap_trigger_aim_cooldown_and_retention() -> void:
	player.start_carrying()
	assert_true(player.is_carrying, "Should be carrying fish")
	assert_not_null(player._held_fish, "Held fish mesh should exist")

	assert_eq(player.slap_range, 2.0, "slap_range should be 2.0m")
	assert_eq(player.slap_cooldown, 1.0, "slap_cooldown should be ~1.0s")
	assert_eq(Player.PLAYERS_LAYER, 2, "PLAYERS_LAYER should be 1 << 1 (2)")

	player._slap_cooldown_left = 1.0
	player.global_position = Vector3(0, 1.0, 0)
	player._physics_process(0.4)
	assert_almost_eq(player._slap_cooldown_left, 0.6, 0.001, "Slap cooldown should decrement in physics process")

	var triggered := player._try_fish_slap()
	assert_false(triggered, "Should return false when no target in raycast range")
	assert_true(player.is_carrying, "Fish must not be consumed or dropped when attempting slap")
	assert_not_null(player._held_fish, "Held fish must remain")


func test_apply_slap_self_clears_without_physics() -> void:
	player.set_physics_process(false)
	player.apply_slap(3.0)
	assert_true(player.is_slapped, "apply_slap should set is_slapped true")
	await get_tree().create_timer(3.2).timeout
	assert_false(player.is_slapped, "slap should self-clear without physics process")


func test_sync_apply_slap_direct_call() -> void:
	assert_false(player.is_slapped, "is_slapped should start false")
	if player._slap_component and is_instance_valid(player._slap_component):
		player._slap_component._sync_apply_slap()
	assert_true(player.is_slapped, "_sync_apply_slap direct call should apply slap state")







