extends GutTest

const MECHANIC := preload("res://systems/fishing/fishing_mechanic.tscn")
const FISH := preload("res://systems/fishing/fish_manager.gd")
var mechanic: Node3D
var rod: Node3D
var roots: Array[Node3D] = []
var peers: Array[ENetMultiplayerPeer] = []


func before_each() -> void:
	mechanic = autofree(MECHANIC.instantiate())
	add_child(mechanic)
	mechanic.set_process(false)
	mechanic.set_physics_process(false)
	rod = autofree(Node3D.new())
	add_child(rod)
	rod.global_position = MapConfig.MAP_CENTER + Vector3(0, 1.6, 0)
	mechanic.set_rod_tip(rod)
	mechanic.cast_target_position = MapConfig.MAP_CENTER + Vector3(20, 0, 0)
	mechanic.current_state = mechanic.State.BITE
	mechanic.hook_type = mechanic.HookType.FISH
	mechanic.escape_time_threshold = 99.0
	mechanic.start_fish_fight()


func after_each() -> void:
	for root in roots:
		get_tree().set_multiplayer(null, root.get_path())
		root.free()
	roots.clear()
	for peer in peers:
		peer.close()
	peers.clear()


func test_scroll_pulls_then_idle_retreats() -> void:
	var start: Vector3 = mechanic.get_fish_position()
	mechanic.notify_scroll()
	mechanic.advance_fight(0.3)
	var pulled: Vector3 = mechanic.get_fish_position()
	assert_lt(pulled.distance_to(rod.global_position), start.distance_to(rod.global_position))
	mechanic.advance_fight(0.3)
	assert_gt(mechanic.get_fish_position().distance_to(rod.global_position), pulled.distance_to(rod.global_position))
	assert_eq(mechanic.cast_target_position, MapConfig.MAP_CENTER + Vector3(20, 0, 0))


func test_exports_control_world_distance() -> void:
	mechanic.fish_pull_strength = 4.0
	mechanic.fish_retreat_speed = 3.0
	mechanic.notify_scroll()
	mechanic.advance_fight(0.25)
	assert_almost_eq(mechanic.get_fish_position().x, 19.0, 0.001)
	mechanic.advance_fight(0.05)
	mechanic.advance_fight(0.5)
	assert_almost_eq(mechanic.get_fish_position().x, 20.3, 0.001)


func test_pulse_expiry_is_independent_of_step_size() -> void:
	mechanic.notify_scroll()
	mechanic.advance_fight(0.5)
	var large_step: Vector3 = mechanic.get_fish_position()
	mechanic.cast_target_position = MapConfig.MAP_CENTER + Vector3(20, 0, 0)
	mechanic.notify_scroll()
	for i in range(5):
		mechanic.advance_fight(0.1)
	assert_almost_eq(mechanic.get_fish_position().distance_to(large_step), 0.0, 0.001)


func test_elapsed_time_alone_cannot_catch() -> void:
	mechanic._fight_target = 0.01
	watch_signals(mechanic)
	mechanic.advance_fight(2.0)
	assert_eq(mechanic.current_state, mechanic.State.BITE)
	assert_signal_not_emitted(mechanic, "reel_success")
	assert_gt(mechanic.get_fish_position().x, 20.0)


func test_large_pull_catches_at_water_boundary_once() -> void:
	mechanic.get_node("FishManager").spawn(mechanic.cast_target_position)
	mechanic.fish_pull_strength = 1000.0
	watch_signals(mechanic)
	mechanic.notify_scroll()
	mechanic.advance_fight(0.3)
	mechanic.advance_fight(1.0)
	assert_eq(mechanic.current_state, mechanic.State.SUCCESS)
	assert_eq(mechanic.personal_catch_count, 1)
	assert_signal_emit_count(mechanic, "reel_success", 1)
	assert_almost_eq(mechanic.get_fish_position().x, MapConfig.ISLAND_RADIUS + FISH.FISH_CLEARANCE, 0.001)
	assert_eq(mechanic.get_node("FishManager").get_fish().global_position, mechanic.get_fish_position())


func test_sweep_stops_before_crossing_island_with_both_endpoints_in_water() -> void:
	var start := MapConfig.MAP_CENTER + Vector3(20, 0, 0)
	var end := MapConfig.MAP_CENTER + Vector3(-20, 0, 0)
	var stopped := FISH.sweep_water(start, end)
	assert_almost_eq(stopped.x, MapConfig.ISLAND_RADIUS + FISH.FISH_CLEARANCE, 0.001)
	for i in range(101):
		assert_false(MapConfig.is_within_radius(start.lerp(stopped, i / 100.0), MapConfig.MAP_CENTER, MapConfig.ISLAND_RADIUS))


func test_retreat_toward_island_is_blocked_without_catch() -> void:
	rod.global_position = MapConfig.MAP_CENTER + Vector3(30, 1, 0)
	mechanic.fish_retreat_speed = 100.0
	mechanic.advance_fight(1.0)
	assert_almost_eq(mechanic.get_fish_position().x, MapConfig.ISLAND_RADIUS + FISH.FISH_CLEARANCE, 0.001)
	assert_eq(mechanic.current_state, mechanic.State.BITE)


func test_spawn_at_center_and_catch_remain_in_water() -> void:
	mechanic.get_node("FishManager").spawn(MapConfig.MAP_CENTER)
	var fish: Node3D = mechanic.get_node("FishManager").get_fish()
	assert_false(MapConfig.is_within_radius(fish.global_position, MapConfig.MAP_CENTER, MapConfig.ISLAND_RADIUS))
	assert_almost_eq(fish.global_position.y, FISH.FISH_SWIM_DEPTH, 0.001)


func test_escape_retreats_before_ending_and_reset_clears_pulse() -> void:
	mechanic.escape_time_threshold = 1.0
	watch_signals(mechanic)
	mechanic.advance_fight(1.1)
	assert_eq(mechanic.current_state, mechanic.State.IDLE)
	assert_gt(mechanic.get_fish_position().x, 20.0)
	assert_signal_emit_count(mechanic, "escape_launch", 1)
	mechanic.notify_scroll()
	mechanic.reset_for_restart()
	assert_eq(mechanic._pull_spike_timer, 0.0)


func _pump() -> void:
	for i in range(10):
		await get_tree().create_timer(0.01).timeout


func _make_peer_fight(owner_index: int = 1) -> Array:
	var server := ENetMultiplayerPeer.new()
	assert_eq(server.create_server(0, 2), OK)
	peers.append(server)
	var port := server.host.get_local_port()
	for i in range(2):
		var peer := ENetMultiplayerPeer.new()
		assert_eq(peer.create_client("127.0.0.1", port), OK)
		peers.append(peer)
	for i in range(3):
		var root := Node3D.new()
		root.name = "TugPeer" + str(i)
		add_child(root)
		roots.append(root)
		var api := SceneMultiplayer.new()
		api.multiplayer_peer = peers[i]
		get_tree().set_multiplayer(api, root.get_path())
	var connection_deadline := Time.get_ticks_msec() + 3000
	while roots[0].multiplayer.get_peers().size() < 2 and Time.get_ticks_msec() < connection_deadline:
		await get_tree().process_frame
	assert_eq(roots[0].multiplayer.get_peers().size(), 2, "Owner and observer connect")
	var owner_id := peers[owner_index].get_unique_id()
	var mechanics := []
	for i in range(3):
		var player: Player = load("res://entities/player/player.tscn").instantiate()
		player.name = "Player_" + str(owner_id)
		roots[i].add_child(player)
		player.set_process(false)
		player.set_physics_process(false)
		player.global_position = MapConfig.MAP_CENTER
		var fm: Node3D = player.fishing_mechanic
		fm.set_process(false)
		fm.set_physics_process(false)
		fm.is_local_render = i == owner_index
		fm.max_tether_range = 100.0
		fm.escape_time_threshold = 99.0
		mechanics.append(fm)
	for i in range(3):
		var zones: Node3D = load("res://systems/zones/zone_manager.tscn").instantiate()
		roots[i].add_child(zones)
		mechanics[i]._zone_manager_ref = zones
	mechanics[0]._zone_manager_ref.set_zones([{"center": MapConfig.MAP_CENTER + Vector3(20, 0, 0), "radius": 5.0}])
	await _pump()
	return mechanics


func _start_peer_fight(copies: Array, owner_index: int = 1) -> void:
	var host: Node3D = copies[0]
	var owner: Node3D = copies[owner_index]
	owner.cast(MapConfig.MAP_CENTER + Vector3(20, 0, 0), 1.0)
	await _pump()
	assert_eq(host.current_state, host.State.CASTING, "Real owner cast RPC starts server lifecycle")
	host.casting_timer.stop()
	host._on_casting_timer_timeout()
	host.bite_timer.stop()
	host._on_bite_timer_timeout()
	await _pump()
	owner.start_fish_fight()
	await _pump()
	assert_true(host._is_fighting, "Owner start RPC accepted")


func test_client_owned_fight_server_simulates_and_observer_converges() -> void:
	var copies := await _make_peer_fight()
	await _start_peer_fight(copies)
	var host: Node3D = copies[0]
	var owner: Node3D = copies[1]
	var observer: Node3D = copies[2]
	var start: Vector3 = host.get_fish_position()
	owner.advance_fight(0.5)
	assert_eq(owner.get_fish_position(), start, "Client cannot simulate movement")
	observer.notify_scroll.rpc_id(1, host.fish_generation)
	await _pump()
	assert_eq(host._pull_spike_timer, 0.0, "Observer cannot control another owner's fish")
	owner.notify_scroll.rpc_id(1, host.fish_generation - 1)
	await _pump()
	assert_eq(host._pull_spike_timer, 0.0, "Stale scroll is rejected")
	owner.notify_scroll.rpc_id(1, host.fish_generation)
	await _pump()
	host._physics_process(0.3)
	await _pump()
	assert_lt(host.get_fish_position().x, start.x)
	assert_eq(owner.get_fish_position(), host.get_fish_position())
	assert_eq(observer.get_fish_position(), host.get_fish_position())
	owner._apply_synced_state({"generation": 999})
	assert_ne(owner.fish_generation, 999, "Direct client snapshot injection rejected")
	observer._apply_synced_state.rpc_id(peers[1].get_unique_id(), {"generation": 999})
	await _pump()
	assert_ne(owner.fish_generation, 999, "Observer snapshot injection rejected")
	watch_signals(owner)
	host.fish_pull_strength = 1000.0
	owner.notify_scroll.rpc_id(1, host.fish_generation)
	await _pump()
	host._physics_process(0.3)
	await _pump()
	host._sync_state_to_clients()
	await _pump()
	assert_eq(owner.current_state, owner.State.SUCCESS)
	assert_eq(observer.current_state, observer.State.SUCCESS)
	assert_signal_emit_count(owner, "reel_success", 1, "Duplicate snapshots do not award twice")
	assert_eq(owner.personal_catch_count, 1)
	assert_false(MapConfig.is_within_radius(observer.get_fish_position(), MapConfig.MAP_CENTER, MapConfig.ISLAND_RADIUS))
	assert_false(observer.has_authoritative_fish_state(), "Terminal fish snapshot releases player sync guard")
	await get_tree().create_timer(0.8).timeout
	host._on_catch_feedback_completed(host.fish_generation)
	await _pump()
	assert_eq(owner.current_state, owner.State.IDLE, "Owner receives final idle snapshot after catch feedback")
	assert_eq(observer.current_state, observer.State.IDLE, "Observer receives final idle snapshot after catch feedback")
	assert_false(owner.has_authoritative_fish_state(), "Final idle snapshot keeps fish authority released")
	assert_false(observer.has_authoritative_fish_state(), "Final idle snapshot keeps observer fish authority released")
	var host_player := host.get_parent() as Player
	host_player.rpc_id(peers[2].get_unique_id(), "_sync_cast_target", MapConfig.MAP_CENTER + Vector3(5, 0, 0))
	host_player.rpc_id(peers[2].get_unique_id(), "_sync_fishing_state", host.State.BITE)
	await _pump()
	assert_eq(observer.current_state, observer.State.BITE, "Observer accepts following player-hook state")
	assert_eq(observer.cast_target_position, MapConfig.MAP_CENTER + Vector3(5, 0, 0))
	var terminal_generation: int = host.fish_generation
	var owner_player := owner.get_parent() as Player
	var observer_player := observer.get_parent() as Player
	host.reset_for_restart()
	await _pump()
	host_player.reset_for_restart()
	owner_player.reset_for_restart()
	observer_player.reset_for_restart()
	await _pump()
	assert_false(host_player.is_carrying)
	assert_false(owner_player.is_carrying)
	assert_false(observer_player.is_carrying)
	assert_gt(host.fish_generation, terminal_generation)
	assert_eq(owner.fish_generation, host.fish_generation, "Reset reaches owner after terminal fish authority release")
	assert_false(owner.has_authoritative_fish_state(), "Reset keeps fish authority released")
	owner.cast(MapConfig.MAP_CENTER + Vector3(20, 0, 0), 1.0)
	await _pump()
	assert_eq(host.current_state, host.State.CASTING, "Owner can cast after terminal reset")
	assert_eq(owner.current_state, owner.State.CASTING)


func test_stale_catch_completion_cannot_end_newer_success() -> void:
	mechanic.current_state = mechanic.State.SUCCESS
	var old_generation: int = mechanic.fish_generation
	mechanic.reset_for_restart()
	mechanic.cast(MapConfig.MAP_CENTER + Vector3(20, 0, 0), 1.0)
	mechanic.current_state = mechanic.State.BITE
	mechanic.hook_type = mechanic.HookType.FISH
	mechanic._is_fighting = true
	mechanic._complete_fight_catch()
	assert_gt(mechanic.fish_generation, old_generation)
	assert_eq(mechanic.current_state, mechanic.State.SUCCESS)
	mechanic._on_catch_feedback_completed(old_generation)
	assert_eq(mechanic.current_state, mechanic.State.SUCCESS, "Old catch completion cannot end newer success")


func test_peer_cancel_rejects_observer_and_stale_requests_after_recast() -> void:
	var copies := await _make_peer_fight()
	await _start_peer_fight(copies)
	var host: Node3D = copies[0]
	var owner: Node3D = copies[1]
	var observer: Node3D = copies[2]
	var old_generation: int = host.fish_generation
	observer._request_fish_cancel.rpc_id(1, old_generation)
	await _pump()
	assert_true(host.is_fighting())
	owner.cancel_fish_fight()
	await _pump()
	assert_eq(observer.current_state, observer.State.IDLE)
	assert_null(observer.get_node("FishManager").get_fish())
	await _start_peer_fight(copies)
	assert_gt(host.fish_generation, old_generation)
	owner._request_fish_cancel.rpc_id(1, old_generation)
	owner.notify_scroll.rpc_id(1, old_generation)
	await _pump()
	assert_true(host.is_fighting())
	assert_eq(host._pull_spike_timer, 0.0)


func test_peer_escape_and_reset_converge_without_duplicate_feedback() -> void:
	var copies := await _make_peer_fight()
	await _start_peer_fight(copies)
	var host: Node3D = copies[0]
	var owner: Node3D = copies[1]
	var observer: Node3D = copies[2]
	watch_signals(owner)
	host.escape_time_threshold = 0.1
	host._physics_process(0.2)
	await _pump()
	host._sync_state_to_clients()
	await _pump()
	assert_eq(owner.current_state, owner.State.IDLE)
	assert_eq(observer.current_state, observer.State.IDLE)
	assert_signal_emit_count(owner, "escape_launch", 1)
	assert_null(observer.get_node("FishManager").get_fish())
	await _start_peer_fight(copies)
	var old_generation: int = host.fish_generation
	host.reset_for_restart()
	await _pump()
	owner.notify_scroll.rpc_id(1, old_generation)
	await _pump()
	assert_eq(owner.fish_generation, host.fish_generation)
	assert_eq(observer.current_state, observer.State.IDLE)
	assert_eq(owner.personal_catch_count, 0)
	assert_false(host.is_fighting())
	assert_eq(host._pull_spike_timer, 0.0)


func test_host_owned_fight_moves_once_on_server_and_replicates() -> void:
	var copies := await _make_peer_fight(0)
	await _start_peer_fight(copies, 0)
	var host: Node3D = copies[0]
	var start: Vector3 = host.get_fish_position()
	host.notify_scroll(host.fish_generation)
	host.advance_fight(0.3)
	assert_eq(host.get_fish_position(), start, "Player update cannot double-step the server fight")
	host._physics_process(0.3)
	await _pump()
	assert_almost_eq(start.distance_to(host.get_fish_position()), host.fish_pull_strength * 0.3, 0.001)
	assert_eq(copies[1].get_fish_position(), host.get_fish_position())
	assert_eq(copies[2].get_fish_position(), host.get_fish_position())
