extends GutTest

var pause_menu: CanvasLayer
var _main: Node3D


func before_each() -> void:
	var existing := get_node_or_null("/root/main")
	if existing:
		existing.free()

	_main = Node3D.new()
	_main.name = "main"
	get_node("/root").add_child(_main)

	var scene := load("res://ui/pause_menu.tscn") as PackedScene
	pause_menu = autofree(scene.instantiate()) as CanvasLayer
	add_child(pause_menu)
	await get_tree().process_frame


func after_each() -> void:
	if _main and is_instance_valid(_main):
		_main.free()
	_main = null


func test_hidden_by_default() -> void:
	assert_false(pause_menu.visible, "Pause menu should be hidden by default")


func test_open_menu() -> void:
	pause_menu.open_menu()
	assert_true(pause_menu.visible, "Pause menu should be visible after open_menu")
	if DisplayServer.get_name() != "headless":
		assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "Mouse mode should be VISIBLE when paused")


func test_close_menu() -> void:
	pause_menu.open_menu()
	pause_menu.close_menu()
	assert_false(pause_menu.visible, "Pause menu should be hidden after close_menu")
	if DisplayServer.get_name() != "headless":
		assert_eq(Input.mouse_mode, Input.MOUSE_MODE_CAPTURED, "Mouse mode should be CAPTURED when unpaused")


func test_ui_cancel_toggles() -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ESCAPE

	# Should open
	pause_menu._unhandled_input(event)
	assert_true(pause_menu.visible, "ui_cancel should open pause menu when hidden")

	# Should close
	pause_menu._unhandled_input(event)
	assert_false(pause_menu.visible, "ui_cancel should close pause menu when visible")


func test_guard_shop_ui_root() -> void:
	var shop_ui := Node.new()
	shop_ui.name = "ShopUI"
	get_tree().root.add_child(shop_ui)
	await get_tree().process_frame
	
	pause_menu.open_menu()
	assert_false(pause_menu.visible, "Pause menu should not open if ShopUI exists at root")
	shop_ui.free()


func test_guard_end_screen() -> void:
	var end_screen := Control.new()
	end_screen.name = "EndScreen"
	end_screen.visible = true
	_main.add_child(end_screen)
	await get_tree().process_frame

	pause_menu.open_menu()
	assert_false(pause_menu.visible, "Pause menu should not open if EndScreen is visible")
	end_screen.free()


func test_tree_paused_stays_false() -> void:
	pause_menu.open_menu()
	assert_false(get_tree().paused, "SceneTree.paused must never be true")
	pause_menu.close_menu()
	assert_false(get_tree().paused, "SceneTree.paused must still be false")


func test_pause_toggled_signal() -> void:
	var gm = get_node("/root/game_manager")
	watch_signals(gm)

	pause_menu.open_menu()
	assert_signal_emitted_with_parameters(gm, "pause_toggled", [true])

	pause_menu.close_menu()
	assert_signal_emitted_with_parameters(gm, "pause_toggled", [false])


func test_all_buttons_exist() -> void:
	assert_not_null(pause_menu.resume_button, "resume_button must exist")
	assert_not_null(pause_menu.mute_button, "mute_button must exist")
	assert_not_null(pause_menu.fullscreen_button, "fullscreen_button must exist")
	assert_not_null(pause_menu.exit_button, "exit_button must exist")
