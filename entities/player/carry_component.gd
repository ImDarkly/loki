class_name CarryComponent extends Node

var _player: Player
var _head: Node3D
var _rod_pivot: Node3D
var _quota_manager_ref: Node
var _danger_manager_ref: Node
var _seagull_manager_ref: Node
var _rock_manager_ref: Node
var _rock_pickup_range: float = 3.0

var is_carrying: bool = false
var holding_rock: bool = false
var holding_shark_bait: bool = false
var _held_fish: Node3D = null
var _held_rock_mesh: MeshInstance3D = null
var _held_bait_mesh: MeshInstance3D = null


func setup(p_player: Player, p_head: Node3D, p_rod_pivot: Node3D, p_quota: Node = null, p_danger: Node = null, p_seagull: Node = null, p_rock: Node = null, p_rock_pickup_range: float = 3.0) -> void:
	_player = p_player
	_head = p_head
	_rod_pivot = p_rod_pivot
	_quota_manager_ref = p_quota if p_quota else get_node_or_null("/root/main/QuotaManager")
	_danger_manager_ref = p_danger if p_danger else get_node_or_null("/root/main/DangerManager")
	_seagull_manager_ref = p_seagull if p_seagull else get_node_or_null("/root/main/SeagullManager")
	_rock_manager_ref = p_rock if p_rock else get_node_or_null("/root/main/RockManager")
	_rock_pickup_range = p_rock_pickup_range


func start_carrying() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_start_carrying.rpc_id(1)
		return
	is_carrying = true
	_show_held_fish_remote()
	if multiplayer.has_multiplayer_peer():
		sync_carrying.rpc(true)
	if _player and _player.has_method("refresh_prompts"):
		_player.refresh_prompts()


func deposit_carried_fish() -> void:
	if not is_carrying:
		return
	if is_instance_valid(_quota_manager_ref) and (not multiplayer.has_multiplayer_peer() or multiplayer.is_server()):
		_quota_manager_ref.report_catch(1)
	elif is_instance_valid(_quota_manager_ref):
		_quota_manager_ref.report_catch.rpc(1)
	_clear_carry()


func drop_carried_fish() -> void:
	if not is_carrying:
		return
	_clear_carry()


func _clear_carry() -> void:
	if not is_carrying:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_clear_carry.rpc_id(1)
		return
	is_carrying = false
	_hide_held_fish_remote()
	if multiplayer.has_multiplayer_peer():
		sync_carrying.rpc(false)
	if _player and _player.has_method("refresh_prompts"):
		_player.refresh_prompts()


func clear_carry() -> void:
	_clear_carry()


func start_holding_shark_bait() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_start_holding_shark_bait.rpc_id(1)
		return
	holding_shark_bait = true
	_show_held_bait_remote()
	if multiplayer.has_multiplayer_peer():
		sync_holding_bait.rpc(true)
	if _player and _player.has_method("refresh_prompts"):
		_player.refresh_prompts()


func clear_holding_shark_bait() -> void:
	if not holding_shark_bait:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_clear_holding_shark_bait.rpc_id(1)
		return
	holding_shark_bait = false
	_hide_held_bait_remote()
	if multiplayer.has_multiplayer_peer():
		sync_holding_bait.rpc(false)
	if _player and _player.has_method("refresh_prompts"):
		_player.refresh_prompts()


func try_pickup_rock() -> bool:
	if is_carrying or holding_rock or holding_shark_bait:
		return false
	if not _rock_manager_ref:
		return false
	var space_state := _player.get_world_3d().direct_space_state if _player else null
	if not space_state:
		return false
	var origin := _player.camera.global_position if _player and is_instance_valid(_player.camera) else Vector3.ZERO
	var dir := -_player.camera.global_transform.basis.z if _player and is_instance_valid(_player.camera) else Vector3.FORWARD
	var params := PhysicsRayQueryParameters3D.new()
	params.from = origin
	params.to = origin + dir * _rock_pickup_range
	params.collision_mask = 4
	var result := space_state.intersect_ray(params)
	if not result:
		return false
	var rock_index: int = _rock_manager_ref.get_nearest_available_point(result.position, 2.0)
	if rock_index == -1:
		return false
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_pickup_rock.rpc_id(1, rock_index)
		return true
	if _rock_manager_ref:
		_rock_manager_ref.request_pickup(rock_index)
	holding_rock = true
	_show_held_rock_remote()
	if multiplayer.has_multiplayer_peer():
		sync_holding_rock.rpc(true)
	if _player and _player.has_method("refresh_prompts"):
		_player.refresh_prompts()
	return true


func throw_rock(launch_speed: float) -> void:
	var rock := RigidBody3D.new()
	rock.name = "ThrownRock"
	rock.gravity_scale = 1.0

	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.25, 0.15, 0.25)
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.5)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	rock.add_child(mi)

	var cs := CollisionShape3D.new()
	cs.shape = BoxShape3D.new()
	cs.shape.size = Vector3(0.25, 0.15, 0.25)
	rock.add_child(cs)

	var rock_pos := _player.camera.global_position + (-_player.camera.global_transform.basis.z * 0.5)
	rock.position = rock_pos
	var throw_dir := -_player.camera.global_transform.basis.z
	rock.linear_velocity = throw_dir * launch_speed + Vector3(0, 3, 0)
	rock.angular_velocity = Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5))
	get_tree().root.add_child(rock)
	
	if _danger_manager_ref:
		if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
			_danger_manager_ref.repel(rock_pos, throw_dir)
		else:
			_danger_manager_ref.repel.rpc(rock_pos, throw_dir)
	if _seagull_manager_ref:
		if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
			_seagull_manager_ref.repel(rock_pos, throw_dir)
		else:
			_seagull_manager_ref.repel.rpc(rock_pos, throw_dir)

	var cleanup := Timer.new()
	cleanup.one_shot = true
	cleanup.timeout.connect(rock.queue_free)
	rock.add_child(cleanup)
	cleanup.start(5.0)

	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_clear_holding_rock.rpc_id(1)
	else:
		holding_rock = false
		_hide_held_rock_remote()
		if multiplayer.has_multiplayer_peer():
			sync_holding_rock.rpc(false)


func _try_place_shark_bait() -> void:
	if not holding_shark_bait:
		return
	var origin := _player.camera.global_position if _player and is_instance_valid(_player.camera) else Vector3.ZERO
	var dir := -_player.camera.global_transform.basis.z if _player and is_instance_valid(_player.camera) else Vector3.FORWARD
	var target := origin + dir * 3.0
	target.y = 0.0
	var shark_bait_manager := get_node_or_null("/root/main/SharkBaitManager")
	if not shark_bait_manager:
		shark_bait_manager = get_node_or_null("../SharkBaitManager")
	if shark_bait_manager and shark_bait_manager.has_method("request_place_shark_bait"):
		if multiplayer.has_multiplayer_peer():
			shark_bait_manager.request_place_shark_bait.rpc(target)
		else:
			shark_bait_manager.request_place_shark_bait(target)


func try_place_shark_bait() -> void:
	_try_place_shark_bait()


func _update_rod_visibility() -> void:
	if _rod_pivot:
		_rod_pivot.visible = not is_carrying and not holding_rock and not holding_shark_bait


func _show_held_fish_remote() -> void:
	if is_instance_valid(_held_fish):
		return
	_update_rod_visibility()
	_held_fish = MeshInstance3D.new()
	var fish_mesh := BoxMesh.new()
	fish_mesh.size = Vector3(0.3, 0.1, 0.5)
	_held_fish.mesh = fish_mesh
	var fish_mat := ORMMaterial3D.new()
	fish_mat.albedo_color = Color(1.0, 0.5, 0.0)
	fish_mat.shading_mode = ORMMaterial3D.SHADING_MODE_UNSHADED
	_held_fish.material_override = fish_mat
	_held_fish.position = Vector3(0, -0.1, -0.5)
	_head.add_child(_held_fish)


func _hide_held_fish_remote() -> void:
	if is_instance_valid(_held_fish):
		_held_fish.queue_free()
		_held_fish = null
	_update_rod_visibility()


func _show_held_rock_remote() -> void:
	if is_instance_valid(_held_rock_mesh):
		return
	_update_rod_visibility()
	_held_rock_mesh = MeshInstance3D.new()
	var rock_mesh := BoxMesh.new()
	rock_mesh.size = Vector3(0.25, 0.15, 0.25)
	_held_rock_mesh.mesh = rock_mesh
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.5, 0.5, 0.5)
	rock_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_held_rock_mesh.material_override = rock_mat
	_held_rock_mesh.position = Vector3(0, -0.1, -0.5)
	_head.add_child(_held_rock_mesh)


func _hide_held_rock_remote() -> void:
	if is_instance_valid(_held_rock_mesh):
		_held_rock_mesh.queue_free()
		_held_rock_mesh = null
	_update_rod_visibility()


func hide_held_rock_remote() -> void:
	_hide_held_rock_remote()


func _show_held_bait_remote() -> void:
	if is_instance_valid(_held_bait_mesh):
		return
	_update_rod_visibility()
	_held_bait_mesh = MeshInstance3D.new()
	var bait_mesh := BoxMesh.new()
	bait_mesh.size = Vector3(0.3, 0.15, 0.25)
	_held_bait_mesh.mesh = bait_mesh
	var bait_mat := StandardMaterial3D.new()
	bait_mat.albedo_color = Color(0.9, 0.2, 0.2)
	bait_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_held_bait_mesh.material_override = bait_mat
	_held_bait_mesh.position = Vector3(0, -0.1, -0.5)
	_head.add_child(_held_bait_mesh)


func _hide_held_bait_remote() -> void:
	if is_instance_valid(_held_bait_mesh):
		_held_bait_mesh.queue_free()
		_held_bait_mesh = null
	_update_rod_visibility()


@rpc("any_peer", "reliable", "call_remote")
func request_start_carrying() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	is_carrying = true
	_show_held_fish_remote()
	if multiplayer.has_multiplayer_peer():
		sync_carrying.rpc(true)
	if _player and _player.has_method("refresh_prompts"):
		_player.refresh_prompts()


@rpc("any_peer", "reliable", "call_remote")
func request_clear_carry() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	is_carrying = false
	_hide_held_fish_remote()
	if multiplayer.has_multiplayer_peer():
		sync_carrying.rpc(false)
	if _player and _player.has_method("refresh_prompts"):
		_player.refresh_prompts()


@rpc("any_peer", "reliable", "call_remote")
func request_pickup_rock(rock_index: int) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if is_carrying or holding_rock or holding_shark_bait:
		return
	if _rock_manager_ref:
		_rock_manager_ref.request_pickup(rock_index)
	holding_rock = true
	_show_held_rock_remote()
	if multiplayer.has_multiplayer_peer():
		sync_holding_rock.rpc(true)
	if _player and _player.has_method("refresh_prompts"):
		_player.refresh_prompts()


@rpc("any_peer", "reliable", "call_remote")
func request_clear_holding_rock() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	holding_rock = false
	_hide_held_rock_remote()
	if multiplayer.has_multiplayer_peer():
		sync_holding_rock.rpc(false)
	if _player and _player.has_method("refresh_prompts"):
		_player.refresh_prompts()


@rpc("any_peer", "reliable", "call_remote")
func request_start_holding_shark_bait() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	holding_shark_bait = true
	_show_held_bait_remote()
	if multiplayer.has_multiplayer_peer():
		sync_holding_bait.rpc(true)
	if _player and _player.has_method("refresh_prompts"):
		_player.refresh_prompts()


@rpc("any_peer", "reliable", "call_remote")
func request_clear_holding_shark_bait() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	holding_shark_bait = false
	_hide_held_bait_remote()
	if multiplayer.has_multiplayer_peer():
		sync_holding_bait.rpc(false)
	if _player and _player.has_method("refresh_prompts"):
		_player.refresh_prompts()


@rpc("authority", "reliable", "call_remote")
func sync_carrying(val: bool) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		return
	is_carrying = val
	if val:
		_show_held_fish_remote()
	else:
		_hide_held_fish_remote()
	if _player and _player.has_method("refresh_prompts"):
		_player.refresh_prompts()


@rpc("authority", "reliable", "call_remote")
func sync_holding_rock(val: bool) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		return
	holding_rock = val
	if val:
		_show_held_rock_remote()
	else:
		_hide_held_rock_remote()
	if _player and _player.has_method("refresh_prompts"):
		_player.refresh_prompts()


@rpc("authority", "reliable", "call_remote")
func sync_holding_bait(val: bool) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		return
	holding_shark_bait = val
	if val:
		_show_held_bait_remote()
	else:
		_hide_held_bait_remote()
	if _player and _player.has_method("refresh_prompts"):
		_player.refresh_prompts()
