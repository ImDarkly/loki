extends GutTest

var world_label_hint: WorldLabelHint


func before_each() -> void:
	world_label_hint = autofree(WorldLabelHint.new())
	world_label_hint.label_text = "Test Hint"
	add_child(world_label_hint)


func after_each() -> void:
	world_label_hint = null


func test_compute_alpha_close() -> void:
	assert_eq(WorldLabelHint._compute_alpha(5.0, 12.0, 20.0), 1.0)
	assert_eq(WorldLabelHint.compute_alpha(5.0, 12.0, 20.0), 1.0)


func test_compute_alpha_at_start() -> void:
	assert_eq(WorldLabelHint._compute_alpha(12.0, 12.0, 20.0), 1.0)


func test_compute_alpha_midpoint() -> void:
	assert_almost_eq(WorldLabelHint._compute_alpha(16.0, 12.0, 20.0), 0.5, 0.001)


func test_compute_alpha_at_end() -> void:
	assert_eq(WorldLabelHint._compute_alpha(20.0, 12.0, 20.0), 0.0)


func test_compute_alpha_beyond() -> void:
	assert_eq(WorldLabelHint._compute_alpha(25.0, 12.0, 20.0), 0.0)


func test_label_created_with_correct_properties() -> void:
	var label := world_label_hint.get_child(0) as Label3D
	
	assert_not_null(label, "WorldLabelHint should create a Label3D child")
	assert_eq(label.billboard, BaseMaterial3D.BILLBOARD_ENABLED)
	assert_true(label.double_sided)
	assert_eq(label.font_size, 48)
	assert_eq(label.outline_size, 12)
	assert_eq(label.pixel_size, 0.005)
	assert_eq(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_eq(label.text, "Test Hint")
	assert_eq(label.position, Vector3(0, 0.9, 0))


func test_label_text_setter_updates_label() -> void:
	world_label_hint.label_text = "Updated Hint"
	var label := world_label_hint.get_child(0) as Label3D
	assert_eq(label.text, "Updated Hint")
