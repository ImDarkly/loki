extends StaticBody3D

@onready var interactable_component: InteractableComponent = $InteractableComponent
@onready var _fill_bar: Node3D = $FillBarRoot
@onready var _fill_mesh: MeshInstance3D = $FillBarRoot/Fill

var _bait_manager: SharkBaitManager = null


func _resolve_bait_manager() -> SharkBaitManager:
	var m := get_node_or_null("../SharkBaitManager") as SharkBaitManager
	if m != null:
		return m
	return get_node_or_null("/root/main/SharkBaitManager") as SharkBaitManager


func _ready() -> void:
	if _fill_mesh and _fill_mesh.material_override:
		_fill_mesh.material_override = _fill_mesh.material_override.duplicate()
	_bait_manager = _resolve_bait_manager()
	if _bait_manager != null:
		if _bait_manager.has_signal("bait_fill_updated"):
			_bait_manager.bait_fill_updated.connect(_update_bar)
		_update_bar(_bait_manager.bait_fill_count, _bait_manager.fill_cost)
	else:
		_update_bar(0, 3)


func _exit_tree() -> void:
	if _bait_manager != null and _bait_manager.has_signal("bait_fill_updated"):
		if _bait_manager.bait_fill_updated.is_connected(_update_bar):
			_bait_manager.bait_fill_updated.disconnect(_update_bar)


func _update_bar(count: int, cost: int) -> void:
	if not _fill_mesh:
		return
	var ratio := clampf(float(count) / max(float(cost), 1.0), 0.0, 1.0)
	_fill_mesh.scale.x = ratio
	var mat := _fill_mesh.material_override as StandardMaterial3D
	if mat != null:
		if count >= cost:
			mat.albedo_color = Color(1.0, 0.2, 0.0, 1.0)
		else:
			mat.albedo_color = Color(0.0, 0.8, 0.0, 1.0)
