extends GutTest


func _assert_visible_geometry(root: Node3D) -> void:
	var visible_meshes := 0
	for visual: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if visual.mesh and visual.is_visible_in_tree() and visual.mesh.get_aabb().size.length() > 0.0:
			visible_meshes += 1
	assert_gt(visible_meshes, 0, "Gameplay object must remain visible without optional models")


func _assert_fallback(root: Node3D, model_path: String, primitive_count: int) -> void:
	var fallback := root.get_node_or_null("Mesh/Fallback")
	if ResourceLoader.exists(model_path):
		assert_null(fallback, "Loaded replacement should remove only its own primitive fallback")
	else:
		assert_not_null(fallback, "Missing replacement must keep the old primitives")
		if fallback:
			assert_eq(fallback.find_children("*", "MeshInstance3D", true, false).size(), primitive_count)
			_assert_visible_geometry(fallback)
	_assert_visible_geometry(root.get_node("Mesh"))


func test_storage_stays_visible_and_depositable_without_boat() -> void:
	var storage := autofree(load("res://entities/storage_box.tscn").instantiate()) as StaticBody3D
	add_child(storage)
	await get_tree().process_frame
	_assert_fallback(storage, "res://entities/storage/assets/kenney_watercraft/boat-fishing-small.glb", 1)
	assert_eq(storage.get_node("CollisionShape3D").shape.size, Vector3(0.8, 0.6, 0.8))
	assert_false(storage.get_node("CollisionShape3D").disabled)
	assert_eq(storage.get_node("InteractableComponent").prompt_text, "Deposit Fish [Right Click]")
	assert_true(storage.get_node("InteractableComponent").is_enabled)


func test_shop_stays_visible_and_interactable_without_canopy() -> void:
	var shop := autofree(load("res://entities/shop_hut.tscn").instantiate()) as StaticBody3D
	add_child(shop)
	await get_tree().process_frame
	_assert_fallback(shop, "res://entities/shop/assets/kenney_miniforest/building-roof.glb", 2)
	assert_eq(shop.get_node("CollisionShape3D").shape.size, Vector3(2, 2, 2))
	assert_false(shop.get_node("CollisionShape3D").disabled)
	assert_eq(shop.get_node("InteractableComponent").prompt_text, "Open Shop")
	assert_true(shop.get_node("InteractableComponent").is_enabled)


func test_fireplace_base_stays_visible_without_sourced_pit() -> void:
	var fireplace := autofree(load("res://entities/fireplace.tscn").instantiate()) as StaticBody3D
	add_child(fireplace)
	await get_tree().process_frame
	_assert_fallback(fireplace, "res://entities/fireplace/assets/kenney_survival/campfire-pit.glb", 4)
	fireplace._update_fireplace_visuals()
	_assert_visible_geometry(fireplace.get_node("Mesh"))
	assert_false(fireplace.get_node("FlameLow").visible)
	assert_almost_eq(fireplace.get_node("CollisionShape3D").shape.radius, 1.1, 0.001)
	assert_eq(fireplace.get_node("Seats/Seat1").position, Vector3(0, 0, 1.8))


func test_each_rock_variant_stays_visible_pickable_and_respawns_without_its_model() -> void:
	var manager := autofree(load("res://systems/rocks/rock_manager.tscn").instantiate()) as Node3D
	add_child(manager)
	await get_tree().process_frame
	for i in range(5):
		var rock := manager.rock_nodes[i] as StaticBody3D
		var visual := rock.get_node("Mesh") as MeshInstance3D
		var collision := rock.get_node("Collision") as CollisionShape3D
		assert_not_null(visual.mesh, "Variant %d must keep visible geometry" % (i + 1))
		if not visual.mesh:
			continue
		assert_true(visual.is_visible_in_tree())
		assert_eq(collision.shape.size, Vector3(0.5, 0.3, 0.5))
		var path := "res://world/assets/quaternius_pirate/Environment_Rock_%d.gltf" % (i + 1)
		if ResourceLoader.exists(path):
			assert_false(visual.mesh is BoxMesh, "Available variants must retain their sourced model")
		else:
			assert_true(visual.mesh is BoxMesh, "Only missing variants should use the old cube")
			assert_eq(visual.mesh.size, Vector3(0.5, 0.3, 0.5))
			assert_eq(visual.scale, Vector3.ONE)
		manager.request_pickup(i)
		assert_false(visual.visible)
		assert_true(collision.disabled)
		manager._cooldowns[i] = 1.0
		manager._on_respawn_tick()
		assert_true(visual.is_visible_in_tree())
		assert_false(collision.disabled)
