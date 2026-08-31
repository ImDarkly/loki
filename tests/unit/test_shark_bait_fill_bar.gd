extends GutTest

var manager: Node3D
var _main: Node3D


func before_each() -> void:
	_main = Node3D.new()
	_main.name = "main"
	get_node("/root").add_child(_main)

	manager = autofree(load("res://systems/shark_bait/shark_bait_manager.tscn").instantiate())
	manager.name = "SharkBaitManager"
	_main.add_child(manager)
	await get_tree().process_frame


func after_each() -> void:
	if _main and is_instance_valid(_main):
		_main.queue_free()
		await get_tree().process_frame
	_main = null


func test_fill_bar_node_and_material_properties() -> void:
	var bait = load("res://entities/shark_bait.tscn").instantiate()
	add_child_autofree(bait)
	
	var fill_root = bait.get_node_or_null("FillBarRoot")
	assert_not_null(fill_root, "Should have FillBarRoot")
	assert_almost_eq(fill_root.position.y, 0.95, 0.001, "FillBarRoot should be positioned at y=0.95")

	var frame = fill_root.get_node_or_null("Frame") as MeshInstance3D
	var fill = fill_root.get_node_or_null("Fill") as MeshInstance3D
	assert_not_null(frame, "Should have Frame mesh")
	assert_not_null(fill, "Should have Fill mesh")

	var frame_mat = frame.material_override as StandardMaterial3D
	var fill_mat = fill.material_override as StandardMaterial3D
	assert_not_null(frame_mat)
	assert_not_null(fill_mat)

	assert_eq(frame_mat.shading_mode, 0, "Frame should be unshaded")
	assert_eq(frame_mat.billboard_mode, 1, "Frame should be billboarded")
	assert_eq(frame_mat.cull_mode, 2, "Frame should be double-sided (cull_mode disabled)")

	assert_eq(fill_mat.shading_mode, 0, "Fill should be unshaded")
	assert_eq(fill_mat.billboard_mode, 1, "Fill should be billboarded")
	assert_eq(fill_mat.cull_mode, 2, "Fill should be double-sided (cull_mode disabled)")


func test_fill_bar_scaling_cost_agnostic() -> void:
	var bait = load("res://entities/shark_bait.tscn").instantiate()
	add_child_autofree(bait)
	var fill = bait.get_node_or_null("FillBarRoot/Fill") as MeshInstance3D

	bait._update_bar(0, 3)
	assert_almost_eq(fill.scale.x, 0.0, 0.001)

	bait._update_bar(1, 3)
	assert_almost_eq(fill.scale.x, 1.0 / 3.0, 0.001)

	bait._update_bar(2, 3)
	assert_almost_eq(fill.scale.x, 2.0 / 3.0, 0.001)

	bait._update_bar(3, 3)
	assert_almost_eq(fill.scale.x, 1.0, 0.001)

	# Cost-agnostic test with custom cost (e.g. cost = 5)
	bait._update_bar(2, 5)
	assert_almost_eq(fill.scale.x, 2.0 / 5.0, 0.001)


func test_fill_bar_color_filling_vs_armed() -> void:
	var bait = load("res://entities/shark_bait.tscn").instantiate()
	add_child_autofree(bait)
	var fill = bait.get_node_or_null("FillBarRoot/Fill") as MeshInstance3D
	var fill_mat = fill.material_override as StandardMaterial3D

	bait._update_bar(0, 3)
	assert_eq(fill_mat.albedo_color, Color(0.0, 0.8, 0.0, 1.0), "Unfilled should be green")

	bait._update_bar(2, 3)
	assert_eq(fill_mat.albedo_color, Color(0.0, 0.8, 0.0, 1.0), "Partially filled should be green")

	bait._update_bar(3, 3)
	assert_eq(fill_mat.albedo_color, Color(1.0, 0.2, 0.0, 1.0), "Fully armed (cost=3) should be red")


func test_fill_bar_signal_driven_update() -> void:
	manager._sync_placed(Vector3(10, 0, 10))
	var bait = manager._bait_instance
	assert_not_null(bait)
	var fill = bait.get_node_or_null("FillBarRoot/Fill") as MeshInstance3D

	manager._sync_fill(2)
	assert_almost_eq(fill.scale.x, 2.0 / 3.0, 0.001, "Fill scale should update via signal/sync")


func test_fill_bar_late_joiner_initial_pull() -> void:
	# Manager already has fill = 2 before bait is instantiated
	manager._sync_fill(2)
	manager._sync_placed(Vector3(10, 0, 10))
	var bait = manager._bait_instance
	assert_not_null(bait)
	var fill = bait.get_node_or_null("FillBarRoot/Fill") as MeshInstance3D
	assert_almost_eq(fill.scale.x, 2.0 / 3.0, 0.001, "Late joiner bait should read initial fill on ready")


func test_fill_bar_consume_resets_to_zero() -> void:
	manager._sync_placed(Vector3(10, 0, 10))
	manager._sync_fill(3)
	var bait = manager._bait_instance
	var fill = bait.get_node_or_null("FillBarRoot/Fill") as MeshInstance3D
	var fill_mat = fill.material_override as StandardMaterial3D
	assert_almost_eq(fill.scale.x, 1.0, 0.001)

	manager.consume_by_shark()
	assert_almost_eq(fill.scale.x, 0.0, 0.001, "Consume should reset fill bar scale to 0")
	assert_eq(fill_mat.albedo_color, Color(0.0, 0.8, 0.0, 1.0), "Consume should reset fill color to green")


func test_fill_bar_no_hud_dependency() -> void:
	var bait = load("res://entities/shark_bait.tscn").instantiate()
	add_child_autofree(bait)
	# Should not throw or error even if no HUD or Manager in scene tree
	bait._update_bar(1, 3)
	var fill = bait.get_node_or_null("FillBarRoot/Fill") as MeshInstance3D
	assert_almost_eq(fill.scale.x, 1.0 / 3.0, 0.001)
