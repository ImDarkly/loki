extends StaticBody3D

@onready var interactable_component = $InteractableComponent
@onready var _count_label: Label3D = $CountLabel
@onready var _quota_manager: Node3D = get_node_or_null("/root/main/QuotaManager")


func _ready() -> void:
	_setup_visual()
	_update_label()
	if _quota_manager and _quota_manager.has_signal("quota_updated"):
		_quota_manager.quota_updated.connect(_on_quota_updated)


func _setup_visual() -> void:
	var path := "res://entities/storage/assets/kenney_watercraft/boat-fishing-small.glb"
	if not ResourceLoader.exists(path):
		push_warning("Storage fishing boat missing or unimported: install Kenney Watercraft boat-fishing-small.glb per ASSETS.md, then import in Godot.")
		return
	var scene := load(path) as PackedScene
	if scene == null or not scene.can_instantiate():
		push_warning("Optional prop is not a PackedScene: %s" % path)
		return
	var instance := scene.instantiate()
	var model := instance as Node3D
	if model == null:
		instance.free()
		push_warning("Optional prop has no Node3D root: %s" % path)
		return
	model.name = "FishingBoat"
	model.scale = Vector3.ONE * 1.859
	model.rotation.y = PI / 2.0
	var layout := MapConfig.layout
	var storage_position := layout.storage_position()
	var ship: Rect2 = layout.decks["Ship"]
	model.position = Vector3(storage_position.x, layout.water_height - 0.45 * model.scale.y,
		ship.position.y - 0.8925 * model.scale.x - 0.3) - storage_position
	$Mesh.add_child(model)
	var root_mesh := model as MeshInstance3D
	var has_visible_mesh := root_mesh != null and root_mesh.mesh != null and root_mesh.mesh.get_surface_count() > 0 and root_mesh.is_visible_in_tree()
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh != null and mesh.mesh.get_surface_count() > 0 and mesh.is_visible_in_tree():
			has_visible_mesh = true
			break
	if not has_visible_mesh:
		model.free()
		push_warning("Optional prop has no visible mesh: %s" % path)
		return
	$Mesh/Fallback.free()


func _on_quota_updated(_value: int) -> void:
	_update_label()


func _update_label() -> void:
	if not _count_label:
		return
	var count: int = 0
	if _quota_manager and "shared_quota" in _quota_manager:
		count = _quota_manager.shared_quota
	_count_label.text = "%d fish in storage" % count
