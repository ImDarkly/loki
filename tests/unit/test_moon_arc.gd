extends GutTest


func test_arc_position_start_horizon() -> void:
	var center := MapConfig.MAP_CENTER
	var pos := MoonArc.calculate_arc_position(0.0, center, MoonArc.ARC_RADIUS, MoonArc.ARC_HEIGHT)
	var expected := center + Vector3(MoonArc.ARC_RADIUS, 0.0, 0.0)
	assert_almost_eq(pos.x, expected.x, 0.001, "Progress 0.0 X should be at horizon start")
	assert_almost_eq(pos.y, expected.y, 0.001, "Progress 0.0 Y should be at horizon start")
	assert_almost_eq(pos.z, expected.z, 0.001, "Progress 0.0 Z should match center")


func test_arc_position_zenith() -> void:
	var center := MapConfig.MAP_CENTER
	var pos := MoonArc.calculate_arc_position(0.5, center, MoonArc.ARC_RADIUS, MoonArc.ARC_HEIGHT)
	var expected := center + Vector3(0.0, MoonArc.ARC_HEIGHT, 0.0)
	assert_almost_eq(pos.x, expected.x, 0.001, "Progress 0.5 X should be at zenith")
	assert_almost_eq(pos.y, expected.y, 0.001, "Progress 0.5 Y should be at zenith height")
	assert_almost_eq(pos.z, expected.z, 0.001, "Progress 0.5 Z should match center")


func test_arc_position_end_horizon() -> void:
	var center := MapConfig.MAP_CENTER
	var pos := MoonArc.calculate_arc_position(1.0, center, MoonArc.ARC_RADIUS, MoonArc.ARC_HEIGHT)
	var expected := center + Vector3(-MoonArc.ARC_RADIUS, 0.0, 0.0)
	assert_almost_eq(pos.x, expected.x, 0.001, "Progress 1.0 X should be at horizon end")
	assert_almost_eq(pos.y, expected.y, 0.001, "Progress 1.0 Y should be at horizon end")
	assert_almost_eq(pos.z, expected.z, 0.001, "Progress 1.0 Z should match center")


func test_arc_position_clamping_below_zero() -> void:
	var center := MapConfig.MAP_CENTER
	var pos_neg := MoonArc.calculate_arc_position(-0.5, center, MoonArc.ARC_RADIUS, MoonArc.ARC_HEIGHT)
	var pos_zero := MoonArc.calculate_arc_position(0.0, center, MoonArc.ARC_RADIUS, MoonArc.ARC_HEIGHT)
	assert_almost_eq(pos_neg.x, pos_zero.x, 0.001, "Negative progress should clamp to 0.0 (X)")
	assert_almost_eq(pos_neg.y, pos_zero.y, 0.001, "Negative progress should clamp to 0.0 (Y)")


func test_arc_position_clamping_above_one() -> void:
	var center := MapConfig.MAP_CENTER
	var pos_high := MoonArc.calculate_arc_position(1.5, center, MoonArc.ARC_RADIUS, MoonArc.ARC_HEIGHT)
	var pos_one := MoonArc.calculate_arc_position(1.0, center, MoonArc.ARC_RADIUS, MoonArc.ARC_HEIGHT)
	assert_almost_eq(pos_high.x, pos_one.x, 0.001, "Progress > 1.0 should clamp to 1.0 (X)")
	assert_almost_eq(pos_high.y, pos_one.y, 0.001, "Progress > 1.0 should clamp to 1.0 (Y)")


func test_arc_position_custom_parameters() -> void:
	var custom_center := Vector3(10, 5, 2)
	var custom_radius := 20.0
	var custom_height := 10.0
	var pos_zenith := MoonArc.calculate_arc_position(0.5, custom_center, custom_radius, custom_height)
	var expected_zenith := custom_center + Vector3(0.0, custom_height, 0.0)
	assert_almost_eq(pos_zenith.x, expected_zenith.x, 0.001, "Custom center/radius zenith X")
	assert_almost_eq(pos_zenith.y, expected_zenith.y, 0.001, "Custom center/height zenith Y")
	assert_almost_eq(pos_zenith.z, expected_zenith.z, 0.001, "Custom center Z (zenith)")

	var pos_start := MoonArc.calculate_arc_position(0.0, custom_center, custom_radius, custom_height)
	var expected_start := custom_center + Vector3(custom_radius, 0.0, 0.0)
	assert_almost_eq(pos_start.x, expected_start.x, 0.001, "Custom radius start X")
	assert_almost_eq(pos_start.y, expected_start.y, 0.001, "Custom radius start Y")

	var pos_end := MoonArc.calculate_arc_position(1.0, custom_center, custom_radius, custom_height)
	var expected_end := custom_center + Vector3(-custom_radius, 0.0, 0.0)
	assert_almost_eq(pos_end.x, expected_end.x, 0.001, "Custom radius end X")
	assert_almost_eq(pos_end.y, expected_end.y, 0.001, "Custom radius end Y")


var moon_arc: MoonArc
var _main: Node3D
var round_manager: Node


func before_each() -> void:
	_main = Node3D.new()
	_main.name = "main"
	get_node("/root").add_child(_main)

	round_manager = Node3D.new()
	round_manager.name = "RoundManager"
	round_manager.set("fishing_active", false)
	round_manager.set("round_duration", 900.0)
	_main.add_child(round_manager)

	moon_arc = load("res://world/moon_arc.tscn").instantiate()
	add_child(moon_arc)
	await get_tree().process_frame


func after_each() -> void:
	if moon_arc and is_instance_valid(moon_arc):
		moon_arc.free()
	moon_arc = null
	if _main and is_instance_valid(_main):
		_main.free()
	_main = null


func test_moon_arc_hidden_initially() -> void:
	assert_false(moon_arc.sprite_3d.visible, "Moon should be hidden initially")


func test_moon_arc_shows_on_false_to_true_edge() -> void:
	round_manager.fishing_active = false
	moon_arc._process(0.01)
	assert_false(moon_arc.sprite_3d.visible, "Moon should be hidden when fishing_active is false")

	round_manager.fishing_active = true
	moon_arc._process(0.01)
	assert_true(moon_arc.sprite_3d.visible, "Moon should become visible on false->true edge")
	var anchor_1 := moon_arc._local_anchor_time
	assert_gt(anchor_1, 0, "Anchor time should be stamped")

	await get_tree().process_frame
	moon_arc._process(0.01)
	assert_eq(moon_arc._local_anchor_time, anchor_1, "Anchor time should not change on subsequent frames while true")


func test_moon_arc_hides_on_true_to_false_edge() -> void:
	round_manager.fishing_active = true
	moon_arc._process(0.01)
	assert_true(moon_arc.sprite_3d.visible, "Moon should be visible when fishing_active is true")

	round_manager.fishing_active = false
	moon_arc._process(0.01)
	assert_false(moon_arc.sprite_3d.visible, "Moon should hide when fishing_active becomes false")


func test_world_setup_instantiates_moon_arc() -> void:
	var world_setup_script = load("res://world/world_setup.gd")
	var world_setup := world_setup_script.new() as Node3D
	_main.add_child(world_setup)
	await get_tree().process_frame

	var found_moon := world_setup.get_node_or_null("MoonArc")
	assert_true(is_instance_valid(found_moon), "WorldSetup should instantiate MoonArc as child")
	world_setup.queue_free()
	await get_tree().process_frame
