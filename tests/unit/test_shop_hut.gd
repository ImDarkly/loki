extends GutTest


func test_blue_canopy_replaces_hut_without_changing_shop_interaction() -> void:
	var shop := autofree(load("res://entities/shop_hut.tscn").instantiate()) as StaticBody3D
	add_child(shop)
	await get_tree().process_frame
	assert_null(shop.get_node_or_null("Roof"), "Primitive roof should be replaced by the canopy")
	assert_eq(shop.collision_layer, 32)
	assert_eq(shop.get_node("CollisionShape3D").shape.size, Vector3(2, 2, 2))
	assert_eq(shop.get_node("InteractableComponent").prompt_text, "Open Shop")
	assert_eq(shop.get_node("WorldLabelHint").label_text, "Shop")
	var visual := shop.get_node_or_null("Mesh")
	assert_not_null(visual, "Shop should have a visual container")
	if visual and ResourceLoader.exists("res://entities/shop/assets/kenney_miniforest/building-roof.glb"):
		assert_gt(visual.find_children("*", "MeshInstance3D", true, false).size(), 0, "Installed canopy should render")


func test_canopy_grounds_on_deck_after_parent_places_shop() -> void:
	var path := "res://entities/shop/assets/kenney_miniforest/building-roof.glb"
	if not ResourceLoader.exists(path):
		pending("Install and import the Mini Forest canopy to check its placement")
		return
	var shop := autofree(load("res://entities/shop_hut.tscn").instantiate()) as StaticBody3D
	add_child(shop)
	await get_tree().process_frame
	var layout := MapConfig.layout
	shop.position = layout.point3(layout.pads[0], layout.deck_height + 1.0)
	await get_tree().process_frame
	assert_eq(shop.position, layout.point3(layout.pads[0], layout.deck_height + 1.0))
	var collision := shop.get_node("CollisionShape3D") as CollisionShape3D
	assert_eq(collision.transform, Transform3D.IDENTITY)
	assert_eq(collision.shape.size, Vector3(2, 2, 2))
	assert_eq(shop.collision_layer, 32)
	assert_eq(shop.get_node("WorldLabelHint").position, Vector3(0, 1, 0))
	assert_eq(shop.get_node("InteractableComponent").prompt_text, "Open Shop")
	var canopy := shop.get_node_or_null("Mesh/Canopy") as Node3D
	assert_not_null(canopy)
	if not canopy:
		return
	assert_eq(canopy.scene_file_path, path, "Shop should render the selected Mini Forest model")
	var visuals := canopy.find_children("*", "MeshInstance3D", true, false)
	assert_eq(visuals.size(), 1)
	if visuals.is_empty():
		return
	var mesh := visuals[0] as MeshInstance3D
	var bounds: AABB = mesh.global_transform * mesh.mesh.get_aabb()
	assert_almost_eq(bounds.position.y, layout.deck_height, 0.001)
	assert_almost_eq(bounds.get_center().x, shop.global_position.x, 0.001)
	assert_almost_eq(bounds.get_center().z, shop.global_position.z, 0.001)
	assert_gt(bounds.size.x, collision.shape.size.x, "Canopy should shelter the shop interaction footprint")
	assert_gt(bounds.size.z, collision.shape.size.z)
	assert_lt(bounds.size.x, collision.shape.size.x * 1.5, "Canopy overhang should remain modest")
	assert_lt(bounds.size.z, collision.shape.size.z * 1.5)


func test_primitive_hut_stays_until_canopy_is_loaded() -> void:
	var shop := autofree(load("res://entities/shop_hut.tscn").instantiate()) as StaticBody3D
	var fallback := shop.get_node_or_null("Mesh/Fallback") as Node3D
	assert_not_null(fallback, "Packed scene should provide the hut before optional assets load")
	if fallback == null:
		return
	var body := fallback.get_node("MeshInstance3D") as MeshInstance3D
	var roof := fallback.get_node("Roof") as MeshInstance3D
	assert_eq(body.mesh.size, Vector3(2, 2, 2))
	assert_eq(roof.mesh.size, Vector3(2.2, 0.2, 2.2))
	assert_eq(roof.position, Vector3(0, 1.1, 0))
	add_child(shop)
	await get_tree().process_frame
	if shop.has_node("Mesh/Canopy"):
		assert_null(shop.get_node_or_null("Mesh/Fallback"), "Successful canopy replaces both primitives immediately")
	else:
		assert_true(body.is_visible_in_tree(), "Failed canopy load keeps shop visible")
		assert_true(roof.is_visible_in_tree())
