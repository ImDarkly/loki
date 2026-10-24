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
	var model := (load(path) as PackedScene).instantiate() as Node3D
	model.name = "FishingBoat"
	model.scale = Vector3.ONE * 1.859
	model.rotation.y = PI / 2.0
	var layout := MapConfig.layout
	var storage_position := layout.storage_position()
	var ship: Rect2 = layout.decks["Ship"]
	model.position = Vector3(storage_position.x, layout.water_height - 0.45 * model.scale.y,
		ship.position.y - 0.8925 * model.scale.x - 0.3) - storage_position
	$Mesh.add_child(model)


func _on_quota_updated(_value: int) -> void:
	_update_label()


func _update_label() -> void:
	if not _count_label:
		return
	var count: int = 0
	if _quota_manager and "shared_quota" in _quota_manager:
		count = _quota_manager.shared_quota
	_count_label.text = "%d fish in storage" % count
