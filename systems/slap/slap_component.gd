class_name SlapComponent
extends Node

@export_range(3.0, 5.0) var slap_duration: float = 3.5
@export var slap_range: float = 2.0
@export var slap_cooldown: float = 1.0

var is_slapped: bool = false
var _slap_time_left: float = 0.0
var _slap_token: int = 0
var _slap_cooldown_left: float = 0.0

var _player: Player = null
var _camera: Camera3D = null
var _players_container: Node = null


func setup(p_player: Player, p_camera: Camera3D, p_players_container: Node) -> void:
	_player = p_player
	_camera = p_camera
	_players_container = p_players_container


func _ready() -> void:
	if not _player or not is_instance_valid(_player):
		_player = get_parent() as Player
	if (not _camera or not is_instance_valid(_camera)) and _player and is_instance_valid(_player) and "camera" in _player and is_instance_valid(_player.camera):
		_camera = _player.camera
	if not _players_container or not is_instance_valid(_players_container):
		_players_container = get_node_or_null("/root/main/Players")


func _physics_process(delta: float) -> void:
	if _slap_cooldown_left > 0.0:
		_slap_cooldown_left -= delta
	if is_slapped:
		_process_slapped(delta)


func _get_slap_target() -> Player:
	var p := _player if is_instance_valid(_player) else (get_parent() as Player if get_parent() is Player else null)
	var space_state := p.get_world_3d().direct_space_state if (p and is_instance_valid(p)) else get_world_3d().direct_space_state
	if space_state == null:
		return null
	var cam := (_camera if is_instance_valid(_camera) else null) if _camera else (p.camera if (p and is_instance_valid(p) and "camera" in p and is_instance_valid(p.camera)) else null)
	if not cam or not is_instance_valid(cam):
		return null
	var origin := cam.global_position
	var dir := -cam.global_transform.basis.z
	var params := PhysicsRayQueryParameters3D.new()
	params.from = origin
	params.to = origin + dir * slap_range
	params.collision_mask = 1 << 1
	params.exclude = [p.get_rid()] if (p and is_instance_valid(p)) else [get_rid()]
	var result := space_state.intersect_ray(params)
	if not result or not result.has("collider"):
		return null
	var collider := result.collider as Node3D
	var current: Node = collider
	while current != null and is_instance_valid(current):
		if current is Player:
			var player := current as Player
			if player != p and is_instance_valid(player):
				return player
		current = current.get_parent()
	return null


func _try_fish_slap() -> bool:
	var target := _get_slap_target()
	if not target or not is_instance_valid(target):
		return false
	if target.player_state != Player.PlayerState.ALIVE or target.is_slapped:
		return false
	_slap_cooldown_left = slap_cooldown
	var target_id := target._parse_owner_id()
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			request_slap(target_id)
		else:
			request_slap.rpc_id(1, target_id)
	else:
		request_slap(target_id)
	return true


func _find_player_by_id(id: int) -> Player:
	var container := _players_container if is_instance_valid(_players_container) else get_node_or_null("/root/main/Players")
	if container and is_instance_valid(container):
		var player := container.get_node_or_null("Player_%d" % id) as Player
		if player and is_instance_valid(player):
			return player
		for child in container.get_children():
			if child is Player and is_instance_valid(child) and child._parse_owner_id() == id:
				return child as Player
	var p := _player if is_instance_valid(_player) else null
	if p and is_instance_valid(p) and p.name == "Player_%d" % id:
		return p
	var parent := get_parent()
	if name == "Player_%d" % id and parent is Player and is_instance_valid(parent):
		return parent as Player
	return null


@rpc("any_peer", "reliable", "call_remote")
func request_slap(target_id: int) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var target := _find_player_by_id(target_id)
	if not target or not is_instance_valid(target):
		return
	if target.player_state != Player.PlayerState.ALIVE or target.is_slapped:
		return
	if multiplayer.has_multiplayer_peer():
		var sender_id := multiplayer.get_remote_sender_id()
		if sender_id == 0:
			sender_id = multiplayer.get_unique_id()
		var attacker := _find_player_by_id(sender_id)
		if attacker == null or not is_instance_valid(attacker):
			return
		var p := _player if is_instance_valid(_player) else null
		if attacker != p:
			return
		if attacker == target:
			return
		if attacker.player_state != Player.PlayerState.ALIVE or attacker.is_slapped:
			return
		if not attacker.is_carrying or attacker.holding_rock or attacker.holding_shark_bait:
			return
		if attacker._slap_cooldown_left > 0.01:
			return
		var dist := attacker.global_position.distance_to(target.global_position)
		if dist > slap_range:
			return
		var to_target := target.global_position - attacker.global_position
		to_target.y = 0
		if to_target.length() > 0.001:
			to_target = to_target.normalized()
			var forward := -attacker.global_transform.basis.z
			forward.y = 0
			if forward.length() > 0.001:
				forward = forward.normalized()
				if forward.dot(to_target) < 0.0:
					return
		_slap_cooldown_left = slap_cooldown
	target.apply_slap()
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		if target._slap_component and is_instance_valid(target._slap_component):
			target._slap_component._sync_apply_slap.rpc()


@rpc("authority", "reliable", "call_remote")
func _sync_apply_slap() -> void:
	if multiplayer.has_multiplayer_peer():
		var sender_id := multiplayer.get_remote_sender_id()
		if sender_id != 0 and sender_id != 1:
			return
	apply_slap()


func apply_slap(duration: float = -1.0) -> void:
	var p := _player if is_instance_valid(_player) else (get_parent() as Player if get_parent() is Player else null)
	if p and is_instance_valid(p) and p.player_state != Player.PlayerState.ALIVE:
		return
	if is_slapped:
		return
	is_slapped = true
	var dur := duration if duration > 0.0 else slap_duration
	_slap_time_left = clamp(dur, 3.0, 5.0)
	_slap_token += 1
	var token := _slap_token
	await get_tree().create_timer(_slap_time_left).timeout
	if token == _slap_token and is_slapped:
		_clear_slap()


func _clear_slap() -> void:
	if not is_slapped:
		return
	_slap_token += 1
	is_slapped = false
	_slap_time_left = 0.0
	var p := _player if is_instance_valid(_player) else (get_parent() as Player if get_parent() is Player else null)
	if p and is_instance_valid(p):
		if p.has_method("_update_prompt_visibility"):
			p._update_prompt_visibility()
		if p.has_method("_update_rock_prompt_visibility"):
			p._update_rock_prompt_visibility()


func _process_slapped(delta: float) -> void:
	_slap_time_left -= delta
	if _slap_time_left <= 0.0:
		_clear_slap()
		return
	var p := _player if is_instance_valid(_player) else (get_parent() as Player if get_parent() is Player else null)
	if not p or not is_instance_valid(p):
		return
	p.velocity.x = 0.0
	p.velocity.z = 0.0
	if not p.is_on_floor():
		var mult := p.fall_gravity_multiplier if p.velocity.y < 0 else 1.0
		p.velocity.y -= p._gravity * mult * delta
	else:
		p.velocity.y = 0.0
	p.move_and_slide()
	p._check_fell_off_island()

	p._sync_tick += 1
	if p._sync_tick >= 2:
		p._sync_tick = 0
		if multiplayer.has_multiplayer_peer() and p._is_local_authority():
			p.rpc("_sync_transform", p.global_position, p.rotation, p.head.rotation)
