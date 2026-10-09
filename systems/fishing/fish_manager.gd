extends Node3D

var _fish_node: Node3D = null
var _shadow_nodes: Array[Node3D] = []
var _shadow_angles: Array[float] = []
var _shadow_center: Vector3 = Vector3.ZERO

const SHADOW_RADIUS := 0.55
const SHADOW_Y_OFFSET := -0.35
const FISH_SWIM_DEPTH := -0.5
const SHADOW_ANGULAR_SPEED := 1.5
const SHADOW_SCALE := Vector3(0.15, 0.05, 0.15)

const GOLDFISH_SCENE := preload("res://systems/fishing/assets/Goldfish.glb")
const CLOWNFISH_SCENE := preload("res://systems/fishing/assets/Clownfish.glb")
const SHADOW_MATERIAL := preload("res://systems/fishing/assets/fish_shadow_material.tres")
const SWIM_ANIMATION := "Fish_Armature|Swimming_Normal"


func _ready() -> void:
	var dbg = get_node_or_null("/root/DebugOverlay")
	if dbg:
		dbg.register_system(name, self)


func spawn(position: Vector3) -> void:
	cleanup()
	var inst := GOLDFISH_SCENE.instantiate() as Node3D
	if not inst:
		return
	inst.scale = Vector3(0.1, 0.1, 0.1)
	add_child(inst)
	inst.top_level = true
	inst.global_position = position + Vector3(0, FISH_SWIM_DEPTH, 0)
	_fish_node = inst
	_play_swim_animation(inst)


func update_fight_position(from_pos: Vector3, to_pos: Vector3, weight: float) -> void:
	if not is_instance_valid(_fish_node):
		return
	var pos := from_pos.lerp(to_pos, clamp(weight, 0.0, 1.0))
	pos.y = FISH_SWIM_DEPTH
	_fish_node.global_position = pos
	var dir := to_pos - from_pos
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		_fish_node.rotation.y = atan2(dir.x, dir.z)


func get_fish() -> Node3D:
	return _fish_node


func cleanup() -> void:
	if is_instance_valid(_fish_node):
		_fish_node.queue_free()
		_fish_node = null


func spawn_shadows(center: Vector3) -> void:
	despawn_shadows()
	_shadow_center = center

	var scenes = [GOLDFISH_SCENE, CLOWNFISH_SCENE]
	for i in range(scenes.size()):
		var scene: PackedScene = scenes[i]
		var inst := scene.instantiate() as Node3D
		if not inst:
			continue

		_apply_shadow_material_recursive(inst)
		inst.scale = SHADOW_SCALE

		add_child(inst)
		inst.top_level = true
		_shadow_nodes.append(inst)
		_shadow_angles.append(float(i) * PI)
		_place_shadow_on_circle(i)
		_play_swim_animation(inst)


func _apply_shadow_material_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.material_override = SHADOW_MATERIAL
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_apply_shadow_material_recursive(child)


func _play_swim_animation(inst: Node) -> void:
	for child in inst.find_children("*", "AnimationPlayer", true, false):
		var player := child as AnimationPlayer
		if player == null or not player.has_animation(SWIM_ANIMATION):
			continue
		var clip := player.get_animation(SWIM_ANIMATION)
		if clip.loop_mode == Animation.LOOP_NONE:
			clip.loop_mode = Animation.LOOP_LINEAR
		player.play(SWIM_ANIMATION)


func despawn_shadows() -> void:
	for node in _shadow_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_shadow_nodes.clear()
	_shadow_angles.clear()
	_shadow_center = Vector3.ZERO


func has_shadows() -> bool:
	for node in _shadow_nodes:
		if is_instance_valid(node):
			return true
	return false


func _place_shadow_on_circle(index: int) -> void:
	var node := _shadow_nodes[index]
	if not is_instance_valid(node):
		return
	var angle := _shadow_angles[index]
	node.global_position = _shadow_center \
		+ Vector3(cos(angle) * SHADOW_RADIUS, SHADOW_Y_OFFSET, sin(angle) * SHADOW_RADIUS)
	var vel := Vector3(-sin(angle), 0.0, cos(angle))
	node.rotation.y = atan2(vel.x, vel.z)


func _process(delta: float) -> void:
	if _shadow_nodes.is_empty():
		return
	for i in range(_shadow_nodes.size()):
		var node := _shadow_nodes[i]
		if not is_instance_valid(node):
			continue
		_shadow_angles[i] += delta * SHADOW_ANGULAR_SPEED
		_place_shadow_on_circle(i)


func _exit_tree() -> void:
	cleanup()
	despawn_shadows()


func get_debug_state() -> Dictionary:
	return {
		"shadow_count": _shadow_nodes.size(),
		"has_shadows": has_shadows(),
		"center": str(_shadow_center)
	}


func get_debug_actions() -> Array[Dictionary]:
	return [
		{"id": "spawn_shadows", "label": "Spawn Shadows"},
		{"id": "clear_shadows", "label": "Clear Shadows"}
	]


func debug_action(action_id: String) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	match action_id:
		"spawn_shadows":
			spawn_shadows(_shadow_center if _shadow_center != Vector3.ZERO else global_position)
		"clear_shadows":
			despawn_shadows()
