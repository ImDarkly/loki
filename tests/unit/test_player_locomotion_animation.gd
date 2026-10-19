extends GutTest

const PLAYER_SCENE := preload("res://entities/player/player.tscn")


func _build_player(node_name: String, parent: Node) -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	player.name = node_name
	parent.add_child(player)
	await get_tree().process_frame
	return player


func test_locomotion_component_selects_kaykit_clips_with_standard_blend() -> void:
	var player := await _build_player("Player_1", self)
	autofree(player)
	var component := player.visual_rig.get_node("PlayerLocomotionAnimation") as PlayerLocomotionAnimation
	var animation_player := component.get_node("AnimationPlayer") as AnimationPlayer

	assert_eq(PlayerVisualRig.LOCOMOTION_BLEND_TIME, 0.15)
	assert_true(animation_player.has_animation(&"general/Idle_A"))
	assert_true(animation_player.has_animation(&"movement/Walking_A"))
	assert_true(animation_player.has_animation(&"movement/Jump_Start"))
	assert_true(animation_player.has_animation(&"movement/Jump_Idle"))
	assert_true(animation_player.has_animation(&"movement/Jump_Land"))
	assert_eq(animation_player.get_animation(&"general/Idle_A").loop_mode, Animation.LOOP_LINEAR)
	assert_eq(animation_player.get_animation(&"movement/Walking_A").loop_mode, Animation.LOOP_LINEAR)
	assert_eq(animation_player.get_animation(&"movement/Jump_Idle").loop_mode, Animation.LOOP_LINEAR)
	component._apply_synced_state(PlayerLocomotionAnimation.State.IDLE)
	assert_eq(animation_player.current_animation, &"general/Idle_A")
	component._apply_synced_state(PlayerLocomotionAnimation.State.WALK)
	assert_eq(animation_player.current_animation, &"movement/Walking_A")
	component._set_state(PlayerLocomotionAnimation.State.LAND)
	component._physics_process(0.01)
	assert_eq(component.get_locomotion_state(), PlayerLocomotionAnimation.State.LAND)


func test_server_snapshot_reaches_remote_player() -> void:
	var server_peer := ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(37930, 2), OK)
	var client_peer := ENetMultiplayerPeer.new()
	client_peer.create_client("127.0.0.1", 37930)
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
	var frames := 0
	while frames < 120 and (client_mp.get_unique_id() == 1 or server_mp.get_peers().is_empty()):
		await get_tree().process_frame
		frames += 1
	var client_id := client_mp.get_unique_id()
	var server_player := await _build_player("Player_%d" % client_id, server_root)
	var server_component := server_player.visual_rig.get_node("PlayerLocomotionAnimation") as PlayerLocomotionAnimation
	server_player.set_multiplayer_authority(client_id)
	server_component._record_state(PlayerLocomotionAnimation.State.AIRBORNE)
	server_component.set_physics_process(false)
	var client_player := await _build_player("Player_%d" % client_id, client_root)
	client_player.set_multiplayer_authority(client_id)
	var client_component := client_player.visual_rig.get_node("PlayerLocomotionAnimation") as PlayerLocomotionAnimation
	client_component.set_physics_process(false)
	frames = 0
	while frames < 120 and client_component.get_locomotion_state() != PlayerLocomotionAnimation.State.AIRBORNE:
		await get_tree().process_frame
		frames += 1
	assert_eq(client_component.get_locomotion_state(), PlayerLocomotionAnimation.State.AIRBORNE, "late join snapshot should be accepted")
	client_component._submit_state.rpc_id(1, PlayerLocomotionAnimation.State.WALK)
	frames = 0
	while frames < 120 and server_component.get_locomotion_state() != PlayerLocomotionAnimation.State.WALK:
		await get_tree().process_frame
		frames += 1
	assert_eq(server_component.get_locomotion_state(), PlayerLocomotionAnimation.State.WALK, "server should accept the owner state report")
	assert_eq(client_component.get_locomotion_state(), PlayerLocomotionAnimation.State.WALK, "server state should reach the client")
	client_component._apply_synced_state.rpc_id(1, PlayerLocomotionAnimation.State.IDLE)
	for frame in range(10):
		await get_tree().process_frame
	assert_eq(server_component.get_locomotion_state(), PlayerLocomotionAnimation.State.WALK, "server should reject a client snapshot")
	assert_eq(client_component.get_locomotion_state(), PlayerLocomotionAnimation.State.WALK, "client snapshot should remain server-controlled")

	server_peer.close()
	client_peer.close()
	get_tree().set_multiplayer(null, server_root.get_path())
	get_tree().set_multiplayer(null, client_root.get_path())
	server_root.queue_free()
	client_root.queue_free()
