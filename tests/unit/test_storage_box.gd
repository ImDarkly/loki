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
