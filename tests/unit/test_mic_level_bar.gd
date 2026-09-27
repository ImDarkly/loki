extends GutTest

var mic_level_bar: CanvasLayer
var voice_chat_manager: Node
var _main: Node3D


func before_each() -> void:
	_main = Node3D.new()
	_main.name = "main"
	get_node("/root").add_child(_main)

	voice_chat_manager = load("res://systems/voice_chat/voice_chat_manager.tscn").instantiate()
	voice_chat_manager.name = "VoiceChatManager"
	voice_chat_manager.auto_create_bus = false
	_main.add_child(voice_chat_manager)

	var scene := load("res://systems/voice_chat/mic_level_bar.tscn")
	mic_level_bar = autofree(scene.instantiate())
	_main.add_child(mic_level_bar)
	await get_tree().process_frame


func after_each() -> void:
	if _main and is_instance_valid(_main):
		_main.free()
	_main = null


func test_mic_dot_click_toggles_manager_mute_flag() -> void:
	assert_false(voice_chat_manager.is_muted)
	var mic_dot := mic_level_bar.get_node("%MicDot") as ColorRect
	assert_not_null(mic_dot, "MicDot should exist")

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	mic_level_bar._on_mic_dot_gui_input(event)
	assert_true(voice_chat_manager.is_muted, "Clicking mic dot should mute voice chat manager")

	mic_level_bar._on_mic_dot_gui_input(event)
	assert_false(voice_chat_manager.is_muted, "Clicking mic dot again should unmute")


func test_mute_state_changed_updates_dot_color_and_db_label() -> void:
	var mic_dot := mic_level_bar.get_node("%MicDot") as ColorRect
	var db_label := mic_level_bar.get_node("%DBLabel") as Label

	voice_chat_manager.set_muted(true)
	await get_tree().process_frame
	mic_level_bar._update_display()

	assert_eq(db_label.text, "MUTED", "DBLabel should show MUTED when muted")
	assert_eq(mic_dot.color, Color(1.0, 0.2, 0.0), "MicDot color should be red when muted")


func test_unmute_restores_visuals() -> void:
	var mic_dot := mic_level_bar.get_node("%MicDot") as ColorRect
	var db_label := mic_level_bar.get_node("%DBLabel") as Label

	voice_chat_manager.set_muted(true)
	await get_tree().process_frame
	mic_level_bar._update_display()

	voice_chat_manager.set_muted(false)
	await get_tree().process_frame
	mic_level_bar._update_display()

	assert_ne(db_label.text, "MUTED", "DBLabel should no longer show MUTED after unmute")
