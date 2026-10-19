extends GutTest

const PLAYER_SCENE := preload("res://entities/player/player.tscn")


func _build_player(node_name: String, parent: Node) -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	player.name = node_name
	player.process_mode = Node.PROCESS_MODE_DISABLED
	parent.add_child(player)
	await get_tree().process_frame
	return player


func _wait_for(condition: Callable) -> void:
	var frames := 0
	while frames < 120 and not condition.call():
		await get_tree().process_frame
		frames += 1


func test_server_replicates_owner_state_late_join_reset_and_rejects_spoofs() -> void:
	var server_peer := ENetMultiplayerPeer.new()
	assert_eq(server_peer.create_server(37931, 3), OK)
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
	var server_mp := SceneMultiplayer.new()
	server_mp.multiplayer_peer = server_peer
	var owner_mp := SceneMultiplayer.new()
	var observer_mp := SceneMultiplayer.new()
	get_tree().set_multiplayer(server_mp, server_root.get_path())
	get_tree().set_multiplayer(owner_mp, owner_root.get_path())
	get_tree().set_multiplayer(observer_mp, observer_root.get_path())

	var server_host := await _build_player("Player_1", server_root)
	var server_host_animation := server_host.visual_rig.get_node("PlayerFishingAnimation") as PlayerFishingAnimation
	server_host_animation._record_state(PlayerFishingAnimation.State.WAIT)
	var observer_host := await _build_player("Player_1", observer_root)
	var observer_host_animation := observer_host.visual_rig.get_node("PlayerFishingAnimation") as PlayerFishingAnimation
	owner_peer.create_client("127.0.0.1", 37931)
	owner_mp.multiplayer_peer = owner_peer
	observer_peer.create_client("127.0.0.1", 37931)
	observer_mp.multiplayer_peer = observer_peer
	await _wait_for(func() -> bool: return owner_mp.get_unique_id() != 1 and observer_mp.get_unique_id() != 1 and server_mp.get_peers().size() == 2)
	observer_host_animation._physics_process(0.0)
	await _wait_for(func() -> bool: return observer_host_animation.get_fishing_state() == PlayerFishingAnimation.State.WAIT)
	assert_eq(observer_host_animation.get_fishing_state(), PlayerFishingAnimation.State.WAIT, "late join should receive the server snapshot")

	var owner_id := owner_mp.get_unique_id()
	var server_owner := await _build_player("Player_%d" % owner_id, server_root)
	server_owner.set_multiplayer_authority(owner_id)
	var owner := await _build_player("Player_%d" % owner_id, owner_root)
	owner.set_multiplayer_authority(owner_id)
	var observer_owner := await _build_player("Player_%d" % owner_id, observer_root)
	observer_owner.set_multiplayer_authority(owner_id)
	var server_animation := server_owner.visual_rig.get_node("PlayerFishingAnimation") as PlayerFishingAnimation
	var owner_animation := owner.visual_rig.get_node("PlayerFishingAnimation") as PlayerFishingAnimation
	var observer_animation := observer_owner.visual_rig.get_node("PlayerFishingAnimation") as PlayerFishingAnimation
	observer_animation._physics_process(0.0)
	owner_animation._set_state(PlayerFishingAnimation.State.REEL)
	owner_animation._submit_state.rpc_id(1, PlayerFishingAnimation.State.REEL)
	await _wait_for(func() -> bool: return server_animation.get_fishing_state() == PlayerFishingAnimation.State.REEL and observer_animation.get_fishing_state() == PlayerFishingAnimation.State.REEL)
	assert_eq(server_animation.get_fishing_state(), PlayerFishingAnimation.State.REEL, "server should accept the owner presentation state")
	assert_eq(observer_animation.get_fishing_state(), PlayerFishingAnimation.State.REEL, "observer should converge on the server state")

	observer_animation._set_state(PlayerFishingAnimation.State.CATCH)
	observer_animation._submit_state.rpc_id(1, PlayerFishingAnimation.State.CATCH)
	await _wait_for(func() -> bool: return observer_animation.get_fishing_state() == PlayerFishingAnimation.State.REEL)
	assert_eq(server_animation.get_fishing_state(), PlayerFishingAnimation.State.REEL, "server should reject a non-owner spoof")
	assert_eq(observer_animation.get_fishing_state(), PlayerFishingAnimation.State.REEL, "spoofing observer should receive the authoritative correction")

	server_animation.reset()
	await _wait_for(func() -> bool: return observer_animation.get_fishing_state() == PlayerFishingAnimation.State.IDLE)
	assert_eq(observer_animation.get_fishing_state(), PlayerFishingAnimation.State.IDLE, "server terminal reset should reach remote observers")

	get_tree().set_multiplayer(null, server_root.get_path())
	get_tree().set_multiplayer(null, owner_root.get_path())
	get_tree().set_multiplayer(null, observer_root.get_path())
	server_peer.close()
	owner_peer.close()
	observer_peer.close()
	server_root.free()
	owner_root.free()
	observer_root.free()


func test_non_alive_player_stays_idle_after_next_physics_tick() -> void:
	var player := await _build_player("Player_1", self)
	autofree(player)
	var component := player.visual_rig.get_node("PlayerFishingAnimation") as PlayerFishingAnimation
	player.fishing_mechanic.current_state = 2
	player.player_state = Player.PlayerState.SPECTATE
	component._set_state(PlayerFishingAnimation.State.WAIT)

	component._physics_process(0.0)

	assert_eq(component.get_fishing_state(), PlayerFishingAnimation.State.IDLE)
