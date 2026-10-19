extends GutTest

const PLAYER_SCENE := preload("res://entities/player/player.tscn")


func _build_player(node_name: String, parent: Node) -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	player.name = node_name
	player.process_mode = Node.PROCESS_MODE_DISABLED
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
	assert_eq(server_peer.create_server(37930, 3), OK)
	var owner_peer := ENetMultiplayerPeer.new()
	var observer_peer := ENetMultiplayerPeer.new()
	var server_root := Node3D.new()
	server_root.name = "ServerRoot"
	add_child(server_root)
	var owner_root := Node3D.new()
	owner_root.name = "OwnerRoot"
	add_child(owner_root)
	var observer_root := Node3D.new()
	observer_root.name = "ObserverRoot"
	add_child(observer_root)
	var server_player := await _build_player("Player_1", server_root)
	var server_component := server_player.visual_rig.get_node("PlayerLocomotionAnimation") as PlayerLocomotionAnimation
	var server_mp := SceneMultiplayer.new()
	server_mp.multiplayer_peer = server_peer
	var owner_mp := SceneMultiplayer.new()
	var observer_mp := SceneMultiplayer.new()
	get_tree().set_multiplayer(server_mp, server_root.get_path())
	get_tree().set_multiplayer(owner_mp, owner_root.get_path())
	get_tree().set_multiplayer(observer_mp, observer_root.get_path())
	var observer_remote_player := await _build_player("Player_1", observer_root)
	var observer_remote_component := observer_remote_player.visual_rig.get_node("PlayerLocomotionAnimation") as PlayerLocomotionAnimation
	owner_peer.create_client("127.0.0.1", 37930)
	owner_mp.multiplayer_peer = owner_peer
	observer_peer.create_client("127.0.0.1", 37930)
	observer_mp.multiplayer_peer = observer_peer
	var frames := 0
	while frames < 120 and (owner_mp.get_unique_id() == 1 or observer_mp.get_unique_id() == 1 or server_mp.get_peers().size() != 2):
		await get_tree().process_frame
		frames += 1
	assert_false(observer_mp.is_server())
	var owner_id := owner_mp.get_unique_id()
	server_component._set_state(PlayerLocomotionAnimation.State.WALK)
	var owner_remote_player := await _build_player("Player_1", owner_root)
	var owner_remote_component := owner_remote_player.visual_rig.get_node("PlayerLocomotionAnimation") as PlayerLocomotionAnimation
	owner_remote_component._physics_process(0.0)
	observer_remote_component._physics_process(0.0)
	frames = 0
	while frames < 120 and (owner_remote_component.get_locomotion_state() != PlayerLocomotionAnimation.State.WALK or observer_remote_component.get_locomotion_state() != PlayerLocomotionAnimation.State.WALK):
		await get_tree().process_frame
		frames += 1
	assert_eq(owner_remote_component.get_locomotion_state(), PlayerLocomotionAnimation.State.WALK, "automatic late-join snapshot should reach the remote replica")
	assert_eq(observer_remote_component.get_locomotion_state(), PlayerLocomotionAnimation.State.WALK, "automatic late-join snapshot should reach every remote replica")

	var server_owner_player := await _build_player("Player_%d" % owner_id, server_root)
	server_owner_player.set_multiplayer_authority(owner_id)
	var server_owner_component := server_owner_player.visual_rig.get_node("PlayerLocomotionAnimation") as PlayerLocomotionAnimation
	server_owner_component._set_state(PlayerLocomotionAnimation.State.WALK)
	var owner_player := await _build_player("Player_%d" % owner_id, owner_root)
	owner_player.set_multiplayer_authority(owner_id)
	var owner_component := owner_player.visual_rig.get_node("PlayerLocomotionAnimation") as PlayerLocomotionAnimation
	var observer_player := await _build_player("Player_%d" % owner_id, observer_root)
	observer_player.set_multiplayer_authority(owner_id)
	var observer_component := observer_player.visual_rig.get_node("PlayerLocomotionAnimation") as PlayerLocomotionAnimation
	observer_component._physics_process(0.0)
	frames = 0
	while frames < 120 and observer_component.get_locomotion_state() != PlayerLocomotionAnimation.State.WALK:
		await get_tree().process_frame
		frames += 1
	assert_eq(observer_component.get_locomotion_state(), PlayerLocomotionAnimation.State.WALK, "observer should receive the seeded state before the live update")
	owner_component._set_state(PlayerLocomotionAnimation.State.IDLE)
	owner_component._submit_state.rpc_id(1, PlayerLocomotionAnimation.State.IDLE)
	frames = 0
	while frames < 120 and (server_owner_component.get_locomotion_state() != PlayerLocomotionAnimation.State.IDLE or observer_component.get_locomotion_state() != PlayerLocomotionAnimation.State.IDLE):
		await get_tree().process_frame
		frames += 1
	assert_eq(server_owner_component.get_locomotion_state(), PlayerLocomotionAnimation.State.IDLE, "server should accept the owner state report")
	assert_eq(observer_component.get_locomotion_state(), PlayerLocomotionAnimation.State.IDLE, "accepted owner state should reach observing peers")
	owner_component._set_state(PlayerLocomotionAnimation.State.WALK)
	server_owner_component._apply_synced_state.rpc_id(owner_id, PlayerLocomotionAnimation.State.IDLE)
	for frame in range(10):
		await get_tree().process_frame
	assert_eq(owner_component.get_locomotion_state(), PlayerLocomotionAnimation.State.WALK, "owner prediction should ignore a stale server echo")
	owner_component._apply_synced_state.rpc_id(1, PlayerLocomotionAnimation.State.WALK)
	for frame in range(10):
		await get_tree().process_frame
	assert_eq(server_owner_component.get_locomotion_state(), PlayerLocomotionAnimation.State.IDLE, "server should reject a client snapshot")
	assert_eq(owner_component.get_locomotion_state(), PlayerLocomotionAnimation.State.WALK, "owner should ignore echoed or spoofed snapshots")

	get_tree().set_multiplayer(null, server_root.get_path())
	get_tree().set_multiplayer(null, owner_root.get_path())
	get_tree().set_multiplayer(null, observer_root.get_path())
	server_peer.close()
	owner_peer.close()
	observer_peer.close()
	server_root.free()
	owner_root.free()
	observer_root.free()
