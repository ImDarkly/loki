extends GutTest

const VICTIM_ID := 20001


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

	var slap_component := SlapComponent.new()
	slap_component.name = "SlapComponent"
	player_node.add_child(slap_component)

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


func _pin_slap_container(player: Player, container: Node) -> SlapComponent:
	var comp := player.get_node("SlapComponent") as SlapComponent
	comp._players_container = container
	return comp


func test_valid_slap_round_trip_syncs_victim_and_cooldown() -> void:
	var server_peer := ENetMultiplayerPeer.new()
	var client_peer := ENetMultiplayerPeer.new()
	var chosen_port := -1
	for port in [37912, 37913, 37914]:
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
	var server_att := await _build_player("Player_%d" % client_id, server_players)
	var server_vic := await _build_player("Player_%d" % VICTIM_ID, server_players)
	var client_att := await _build_player("Player_%d" % client_id, client_players)
	var client_vic := await _build_player("Player_%d" % VICTIM_ID, client_players)

	var server_att_comp := _pin_slap_container(server_att, server_players)
	var server_vic_comp := _pin_slap_container(server_vic, server_players)
	var client_att_comp := _pin_slap_container(client_att, client_players)
	var client_vic_comp := _pin_slap_container(client_vic, client_players)

	for p in [server_att, server_vic, client_att, client_vic]:
		p.player_state = Player.PlayerState.ALIVE
	server_att.global_position = Vector3(0, 0, 0)
	server_vic.global_position = Vector3(0, 0, -1.5)
	client_att.global_position = Vector3(0, 0, 0)
	client_vic.global_position = Vector3(0, 0, -1.5)
	server_att.start_carrying()
	assert_true(server_att.is_carrying, "server attacker should carry a fish for a valid slap")
	assert_false(client_vic.is_slapped, "client victim should start unslapped")
	assert_eq(client_att._slap_cooldown_left, 0.0, "client attacker should start off cooldown")

	client_att_comp.request_slap.rpc_id(1, VICTIM_ID)

	frames = 0
	while frames < 120 and (not client_vic.is_slapped or client_att._slap_cooldown_left <= 0.0):
		await get_tree().process_frame
		frames += 1

	assert_true(server_vic.is_slapped, "server victim should be slapped on valid request")
	assert_true(client_vic.is_slapped, "client victim should converge via _sync_apply_slap broadcast")
	assert_gt(server_att_comp._slap_cooldown_left, 0.0, "server attacker cooldown should be set")
	assert_gt(client_att_comp._slap_cooldown_left, 0.0, "client attacker should converge via _sync_slap_cooldown ack")
	assert_gt(server_vic_comp._slap_time_left, 0.0, "server victim slap timer should be set")
	assert_gt(client_vic_comp._slap_time_left, 0.0, "client victim slap timer should be set")

	server_peer.close()
	client_peer.close()
	get_tree().set_multiplayer(null, server_root.get_path())
	get_tree().set_multiplayer(null, client_root.get_path())
	server_root.queue_free()
	client_root.queue_free()


func test_invalid_slap_leaves_both_unslapped_and_no_cooldown() -> void:
	var server_peer := ENetMultiplayerPeer.new()
	var client_peer := ENetMultiplayerPeer.new()
	var chosen_port := -1
	for port in [37915, 37916, 37917]:
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

	var client_id := client_mp.get_unique_id()
	var server_att := await _build_player("Player_%d" % client_id, server_players)
	var server_vic := await _build_player("Player_%d" % VICTIM_ID, server_players)
	var client_att := await _build_player("Player_%d" % client_id, client_players)
	var client_vic := await _build_player("Player_%d" % VICTIM_ID, client_players)

	_pin_slap_container(server_att, server_players)
	_pin_slap_container(server_vic, server_players)
	var client_att_comp := _pin_slap_container(client_att, client_players)
	_pin_slap_container(client_vic, client_players)

	for p in [server_att, server_vic, client_att, client_vic]:
		p.player_state = Player.PlayerState.ALIVE
	server_att.global_position = Vector3(0, 0, 0)
	server_vic.global_position = Vector3(0, 0, -1.5)
	client_att.global_position = Vector3(0, 0, 0)
	client_vic.global_position = Vector3(0, 0, -1.5)
	assert_false(server_att.is_carrying, "server attacker should not carry so the request is invalid")

	client_att_comp.request_slap.rpc_id(1, VICTIM_ID)

	frames = 0
	while frames < 60:
		await get_tree().process_frame
		frames += 1

	assert_false(server_vic.is_slapped, "server victim should stay unslapped on invalid request")
	assert_false(client_vic.is_slapped, "client victim should stay unslapped on invalid request")
	assert_eq(server_att._slap_cooldown_left, 0.0, "server attacker cooldown should stay 0 on invalid request")
	assert_eq(client_att._slap_cooldown_left, 0.0, "client attacker cooldown should stay 0 without optimistic set or server ack")

	server_peer.close()
	client_peer.close()
	get_tree().set_multiplayer(null, server_root.get_path())
	get_tree().set_multiplayer(null, client_root.get_path())
	server_root.queue_free()
	client_root.queue_free()


func test_spoof_client_local_request_rejected() -> void:
	var server_peer := ENetMultiplayerPeer.new()
	var client_peer := ENetMultiplayerPeer.new()
	var chosen_port := -1
	for port in [37918, 37919, 37920]:
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

	var client_id := client_mp.get_unique_id()
	var server_att := await _build_player("Player_%d" % client_id, server_players)
	var server_vic := await _build_player("Player_%d" % VICTIM_ID, server_players)
	var client_att := await _build_player("Player_%d" % client_id, client_players)
	var client_vic := await _build_player("Player_%d" % VICTIM_ID, client_players)

	var server_att_comp := _pin_slap_container(server_att, server_players)
	_pin_slap_container(server_vic, server_players)
	var client_att_comp := _pin_slap_container(client_att, client_players)
	_pin_slap_container(client_vic, client_players)

	for p in [server_att, server_vic, client_att, client_vic]:
		p.player_state = Player.PlayerState.ALIVE

	assert_true(server_att_comp.has_method("_sync_slap_cooldown"), "cooldown ack RPC should exist")
	assert_true(client_att_comp.has_method("_sync_slap_cooldown"), "cooldown ack RPC should exist")

	client_att_comp.request_slap(VICTIM_ID)

	assert_false(client_vic.is_slapped, "direct client request_slap should hit the server gate and apply nothing")
	assert_false(server_vic.is_slapped, "server victim should stay unslapped after spoofed local request")
	assert_eq(client_att_comp._slap_cooldown_left, 0.0, "spoofed local request should set no cooldown")

	server_peer.close()
	client_peer.close()
	get_tree().set_multiplayer(null, server_root.get_path())
	get_tree().set_multiplayer(null, client_root.get_path())
	server_root.queue_free()
	client_root.queue_free()
