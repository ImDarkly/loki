class_name InteractionComponent extends Node

@export var interact_range: float = 3.0
@export var rock_pickup_range: float = 3.0

var _carry: CarryComponent
var _player: Player
var _camera: Camera3D
var _head: Node3D
var _rock_manager_ref: Node
var _ray_hit_box: bool = false
var _ray_rock: bool = false
var _is_shop_open: bool = false
var _interact_prompt: CanvasLayer = null


func setup(p_carry: CarryComponent, p_player: Player, p_camera: Camera3D, p_head: Node3D, p_rock_manager: Node = null) -> void:
	_carry = p_carry
	_player = p_player
	_camera = p_camera
	_head = p_head
	_rock_manager_ref = p_rock_manager if p_rock_manager else get_node_or_null("/root/main/RockManager")
	_setup_interact_prompt()


func tick(delta: float, is_carrying: bool, holding_rock: bool, holding_shark_bait: bool) -> void:
	if _player.player_state == Player.PlayerState.FLOATING:
		_ray_hit_box = false
		_ray_rock = false
		_update_prompt_visibility()
		_update_rock_prompt_visibility()
		return
	_update_interact_raycast()
	_update_rock_raycast()
	_update_prompt_visibility()
	_update_rock_prompt_visibility()


func _setup_interact_prompt() -> void:
	_interact_prompt = CanvasLayer.new()
	_interact_prompt.name = "InteractPrompt"
	_interact_prompt.layer = 130
	var label := Label.new()
	label.name = "PromptLabel"
	label.text = "Deposit Fish [Right Click]"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.offset_left = -150
	label.offset_top = -25
	label.offset_right = 150
	label.offset_bottom = 25
	var font_size := 24
	label.add_theme_font_size_override("font_size", font_size)
	label.visible = false
	_interact_prompt.add_child(label)

	var rock_label := Label.new()
	rock_label.name = "RockPromptLabel"
	rock_label.text = "Pick up rock [Left Click]"
	rock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rock_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	rock_label.offset_left = -150
	rock_label.offset_top = -60
	rock_label.offset_right = 150
	rock_label.offset_bottom = -10
	rock_label.add_theme_font_size_override("font_size", font_size)
	rock_label.visible = false
	_interact_prompt.add_child(rock_label)

	_head.add_child(_interact_prompt)


func _update_interact_raycast() -> void:
	if not _camera or not is_instance_valid(_camera):
		return
	var space_state := _player.get_world_3d().direct_space_state if _player else null
	if space_state == null:
		return
	var origin := _camera.global_position
	var dir := -_camera.global_transform.basis.z
	var params := PhysicsRayQueryParameters3D.new()
	params.from = origin
	params.to = origin + dir * interact_range
	params.collision_mask = 1 << 5
	var result := space_state.intersect_ray(params)

	var hit_node = result.get("collider") if result else null
	var interactable = hit_node.get_node_or_null("InteractableComponent") if hit_node and hit_node.has_method("get_node_or_null") else null
	_ray_hit_box = interactable != null and interactable.is_enabled

	_update_prompt_visibility(interactable)


func _update_prompt_visibility(interactable = null) -> void:
	if not is_instance_valid(_interact_prompt):
		return
	var label := _interact_prompt.get_node_or_null("PromptLabel") as Label
	if not label:
		return
	
	if _ray_hit_box and interactable and not _is_shop_open and (_carry.is_carrying or interactable.show_prompt_without_carrying):
		label.text = interactable.prompt_text
		label.add_theme_color_override("font_color", interactable.prompt_color)
		label.visible = true
	else:
		label.visible = false


func _update_rock_raycast() -> void:
	if _carry.is_carrying or _carry.holding_rock or _carry.holding_shark_bait:
		if _ray_rock:
			_ray_rock = false
			_update_rock_prompt_visibility()
		return
	if not _rock_manager_ref:
		return
	if not _camera or not is_instance_valid(_camera):
		return
	var space_state := _player.get_world_3d().direct_space_state if _player else null
	if space_state == null:
		return
	var origin := _camera.global_position
	var dir := -_camera.global_transform.basis.z
	var params := PhysicsRayQueryParameters3D.new()
	params.from = origin
	params.to = origin + dir * rock_pickup_range
	params.collision_mask = 4
	var result := space_state.intersect_ray(params)
	var hit_rock := false
	if result:
		var rock_index: int = _rock_manager_ref.get_nearest_available_point(result.position, 2.0)
		hit_rock = rock_index != -1
	if hit_rock != _ray_rock:
		_ray_rock = hit_rock
		_update_rock_prompt_visibility()


func _update_rock_prompt_visibility() -> void:
	if not is_instance_valid(_interact_prompt):
		return
	var label := _interact_prompt.get_node_or_null("RockPromptLabel") as Label
	if not label:
		return
	label.visible = _ray_rock and not _is_shop_open


func _on_shop_toggled(is_open: bool) -> void:
	_is_shop_open = is_open
	_update_prompt_visibility()
	_update_rock_prompt_visibility()


func on_shop_toggled(is_open: bool) -> void:
	_on_shop_toggled(is_open)


func handle_interact() -> bool:
	if _carry.holding_shark_bait:
		_carry.try_place_shark_bait()
		return true
	if _ray_hit_box:
		if not _camera or not is_instance_valid(_camera):
			return false
		var space_state := _player.get_world_3d().direct_space_state if _player else null
		if space_state == null:
			return false
		var origin := _camera.global_position
		var dir := -_camera.global_transform.basis.z
		var params := PhysicsRayQueryParameters3D.new()
		params.from = origin
		params.to = origin + dir * interact_range
		params.collision_mask = 1 << 5
		var result := space_state.intersect_ray(params)
		
		if result and result.collider:
			var interactable = result.collider.get_node_or_null("InteractableComponent")
			if interactable and interactable.is_enabled:
				interactable.interacted.emit(_player)
				if _carry.is_carrying and result.collider.is_in_group("storage_box"):
					_carry.deposit_carried_fish()
				elif _carry.is_carrying and result.collider.is_in_group("shark_bait"):
					var shark_bait_manager := get_node_or_null("/root/main/SharkBaitManager")
					if shark_bait_manager and shark_bait_manager.has_method("request_deposit_shark_bait"):
						if multiplayer.has_multiplayer_peer():
							shark_bait_manager.request_deposit_shark_bait.rpc()
						else:
							shark_bait_manager.request_deposit_shark_bait()
				return true
	return false


func handle_cast_line(launch_speed: float) -> bool:
	if _player.is_slapped:
		return false
	if _player.sitting_heal and _player.sitting_heal.is_sitting:
		return false
	if _carry.is_carrying and not _carry.holding_rock and not _carry.holding_shark_bait:
		if _player.slap_component and _player.slap_component.slap_cooldown_left <= 0.0:
			if _player.try_fish_slap():
				return true
		return false
	if _carry.holding_rock:
		_carry.throw_rock(launch_speed)
		return true
	elif _carry.holding_shark_bait:
		_carry.try_place_shark_bait()
		return true
	elif not _carry.is_carrying and _player.fishing_mechanic.can_cast():
		var rod_tip: Vector3 = _player.fishing_mechanic.get_rod_tip_position()
		var dir := -_camera.global_transform.basis.z
		var v := dir * launch_speed
		var discriminant: float = v.y * v.y + 2.0 * _player.gravity * rod_tip.y
		var flight_time := (v.y + sqrt(max(discriminant, 0.0))) / _player.gravity
		flight_time = max(flight_time, 0.1)
		var target := Vector3(rod_tip.x + v.x * flight_time, 0.0, rod_tip.z + v.z * flight_time)
		var offset := Vector2(target.x - _player.global_position.x, target.z - _player.global_position.z)
		if offset.length() > _player.max_cast_range:
			offset = offset.normalized() * _player.max_cast_range
			target.x = _player.global_position.x + offset.x
			target.z = _player.global_position.z + offset.y
		_player.fishing_mechanic.cast(target, flight_time)
		return true
	elif not _carry.is_carrying:
		_carry.try_pickup_rock()
		return true
	return false


func refresh_prompts() -> void:
	_update_prompt_visibility()
	_update_rock_prompt_visibility()


func set_prompt_visibility(visible: bool) -> void:
	if is_instance_valid(_interact_prompt):
		_interact_prompt.visible = visible
