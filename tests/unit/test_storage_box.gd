extends GutTest

var storage_box: StaticBody3D
var quota_manager: Node3D
var _main: Node3D


func before_each() -> void:
	_main = autofree(Node3D.new())
	_main.name = "main"
	get_node("/root").add_child(_main)

	quota_manager = load("res://systems/quota/quota_manager.tscn").instantiate()
	autofree(quota_manager)
	quota_manager.name = "QuotaManager"
	_main.add_child(quota_manager)

	storage_box = autofree(load("res://entities/storage_box.tscn").instantiate())
	add_child(storage_box)
	await get_tree().process_frame


func after_each() -> void:
	storage_box = null
	_main = null


func _get_label() -> Label3D:
	return storage_box.get_node("CountLabel") as Label3D


func test_initial_label_shows_zero_fish() -> void:
	assert_eq(_get_label().text, "0 fish in storage")


func test_initial_label_shows_current_quota_for_late_joiner() -> void:
	storage_box.queue_free()
	quota_manager.shared_quota = 7
	storage_box = autofree(load("res://entities/storage_box.tscn").instantiate())
	add_child(storage_box)
	await get_tree().process_frame
	assert_eq(_get_label().text, "7 fish in storage")


func test_label_updates_when_quota_increases_deposit() -> void:
	quota_manager.shared_quota = 3
	quota_manager.quota_updated.emit(3)
	assert_eq(_get_label().text, "3 fish in storage")
	quota_manager.shared_quota = 4
	quota_manager.quota_updated.emit(4)
	assert_eq(_get_label().text, "4 fish in storage")


func test_label_updates_when_quota_decreases_after_sale() -> void:
	quota_manager.shared_quota = 5
	quota_manager.quota_updated.emit(5)
	assert_eq(_get_label().text, "5 fish in storage")
	quota_manager.shared_quota = 0
	quota_manager.quota_updated.emit(0)
	assert_eq(_get_label().text, "0 fish in storage")


func test_label_format_is_count_fish_in_storage() -> void:
	quota_manager.shared_quota = 1
	quota_manager.quota_updated.emit(1)
	assert_string_contains(_get_label().text, "fish in storage")
	quota_manager.shared_quota = 12
	quota_manager.quota_updated.emit(12)
	assert_eq(_get_label().text, "12 fish in storage")


func test_label_is_billboarded() -> void:
	var label := _get_label()
	assert_eq(label.billboard, 1, "CountLabel should be billboarded (billboard=1)")


func test_label_positioned_above_box() -> void:
	var label := _get_label()
	assert_gt(label.position.y, 0.5, "Label should be above the box mesh (y > 0.5)")


func test_label_remains_legible_properties() -> void:
	var label := _get_label()
	assert_true(label.double_sided, "Label should be double-sided for any angle")


func test_storage_box_has_world_label_hint() -> void:
	var hint = storage_box.get_node_or_null("WorldLabelHint") as WorldLabelHint
	assert_not_null(hint, "StorageBox should have WorldLabelHint")
	assert_eq(hint.label_text, "Storage")
	var count_label = storage_box.get_node_or_null("CountLabel") as Label3D
	assert_not_null(count_label, "StorageBox should still have CountLabel coexisting")


func test_quota_update_leaves_world_label_hint_unchanged() -> void:
	var hint = storage_box.get_node_or_null("WorldLabelHint") as WorldLabelHint
	assert_eq(hint.label_text, "Storage")
	quota_manager.shared_quota = 5
	quota_manager.quota_updated.emit(5)
	assert_eq(hint.label_text, "Storage", "WorldLabelHint text should remain 'Storage' when quota updates")


func test_fishing_boat_replaces_box_without_changing_deposit_collision() -> void:
	var visual := storage_box.get_node("Mesh")
	assert_false(visual is MeshInstance3D, "Storage visual should no longer be a primitive box")
	assert_eq(storage_box.collision_layer, 32)
	assert_eq(storage_box.get_node("CollisionShape3D").shape.size, Vector3(0.8, 0.6, 0.8))
	assert_eq(storage_box.interactable_component.prompt_text, "Deposit Fish [Right Click]")
	if ResourceLoader.exists("res://entities/storage/assets/kenney_watercraft/boat-fishing-small.glb"):
		assert_gt(visual.find_children("*", "MeshInstance3D", true, false).size(), 0, "Installed fishing boat should render")


func test_fishing_boat_floats_beside_ship_after_parent_places_storage() -> void:
	var path := "res://entities/storage/assets/kenney_watercraft/boat-fishing-small.glb"
	if not ResourceLoader.exists(path):
		pending("Install and import the storage fishing boat to check its water placement")
		return
	var collision := storage_box.get_node("CollisionShape3D") as CollisionShape3D
	var label := _get_label()
	var hint := storage_box.get_node("WorldLabelHint") as Node3D
	assert_eq(collision.position, Vector3.ZERO)
	assert_eq(label.position, Vector3(0, 0.9, 0))
	assert_eq(hint.position, Vector3(0, 0.4, 0))
	var collision_transform := collision.transform
	var label_transform := label.transform
	var hint_transform := hint.transform
	var layout := MapConfig.layout
	storage_box.position = layout.storage_position()
	await get_tree().process_frame
	assert_eq(storage_box.position, layout.storage_position())
	assert_eq(collision.transform, collision_transform)
	assert_eq(label.transform, label_transform)
	assert_eq(hint.transform, hint_transform)
	assert_true(layout.is_walkable(storage_box.global_position), "Deposit interaction stays reachable on deck")
	var visuals := storage_box.get_node("Mesh").find_children("*", "MeshInstance3D", true, false)
	assert_eq(visuals.size(), 1, "Fishing boat should render its complete sourced mesh")
	if visuals.is_empty():
		return
	var mesh := visuals[0] as MeshInstance3D
	var bounds: AABB = mesh.global_transform * mesh.mesh.get_aabb()
	var ship: Rect2 = layout.decks["Ship"]
	assert_gt(bounds.size.x, 7.0, "Storage boat should have a substantial fishing boat silhouette")
	assert_lt(bounds.size.x, 7.4, "Storage boat should remain within its intended length")
	assert_lt(bounds.end.z, ship.position.y, "Entire hull should clear the ship deck")
	assert_almost_eq(bounds.get_center().x, storage_box.global_position.x, 0.001)
	assert_lt(bounds.position.y, layout.water_height, "Keel should sit below the waterline")
	assert_gte(bounds.position.y, layout.water_height - 0.95, "Keel draft should stay within the intended waterline")
	assert_lte(bounds.position.y, layout.water_height - 0.75, "Hull should sit sufficiently below the waterline")
	assert_gt(bounds.end.y, layout.water_height, "Boat should remain above water")
	for x in [bounds.position.x, bounds.end.x]:
		for z in [bounds.position.z, bounds.end.z]:
			assert_false(layout.is_walkable(Vector3(x, layout.water_height, z)), "Boat corners should be over water")


func test_primitive_box_stays_until_fishing_boat_is_loaded() -> void:
	var storage := autofree(load("res://entities/storage_box.tscn").instantiate()) as StaticBody3D
	var fallback := storage.get_node_or_null("Mesh/Fallback") as Node3D
	assert_not_null(fallback, "Packed scene should provide a primitive before optional assets load")
	if fallback == null:
		return
	var box := fallback.get_node("Box") as MeshInstance3D
	assert_eq(box.mesh.size, Vector3(0.8, 0.6, 0.8))
	assert_true(box.visible)
	add_child(storage)
	await get_tree().process_frame
	if storage.has_node("Mesh/FishingBoat"):
		assert_null(storage.get_node_or_null("Mesh/Fallback"), "Successful boat replaces the primitive immediately")
	else:
		assert_true(box.is_visible_in_tree(), "Failed boat load keeps storage visible")
