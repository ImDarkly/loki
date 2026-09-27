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


func test_mute_button_toggles_voice_chat_and_updates_text() -> void:
	var players_node := Node3D.new()
	players_node.name = "Players"
	_main.add_child(players_node)

	var peer_id := multiplayer.get_unique_id()
	var player_node := Node3D.new()
	player_node.name = "Player_%d" % peer_id
	players_node.add_child(player_node)

	var vc := Node.new()
	vc.name = "VoiceChatManager"
	vc.set_script(load("res://systems/voice_chat/voice_chat_manager.gd"))
	vc.auto_create_bus = false
	player_node.add_child(vc)

	pause_menu.open_menu()
	assert_eq(pause_menu.mute_button.text, "Mute Voice Chat")
	assert_false(vc.is_muted)

	pause_menu.mute_button.pressed.emit()
	assert_true(vc.is_muted, "Pressing mute button should set is_muted to true")
	assert_eq(pause_menu.mute_button.text, "Unmute Voice Chat", "Button text should flip to Unmute Voice Chat")

	pause_menu.mute_button.pressed.emit()
	assert_false(vc.is_muted, "Pressing mute button again should unmute")
	assert_eq(pause_menu.mute_button.text, "Mute Voice Chat", "Button text should flip back to Mute Voice Chat")


func test_open_menu_refreshes_mute_label() -> void:
	var players_node := Node3D.new()
	players_node.name = "Players"
	_main.add_child(players_node)

	var player_node := Node3D.new()
	player_node.name = "Player_999"
	players_node.add_child(player_node)

	var vc := Node.new()
	vc.name = "VoiceChatManager"
	vc.set_script(load("res://systems/voice_chat/voice_chat_manager.gd"))
	vc.auto_create_bus = false
	vc.is_muted = true
	player_node.add_child(vc)

	pause_menu.open_menu()
	assert_eq(pause_menu.mute_button.text, "Unmute Voice Chat", "open_menu should refresh button text using fallback scan")


func test_single_player_fallback_scan_path() -> void:
	var players_node := Node3D.new()
	players_node.name = "Players"
	_main.add_child(players_node)

	var player_node := Node3D.new()
	player_node.name = "SomeArbitraryPlayerName"
	players_node.add_child(player_node)

	var vc := Node.new()
	vc.name = "VoiceChatManager"
	vc.set_script(load("res://systems/voice_chat/voice_chat_manager.gd"))
	vc.auto_create_bus = false
	vc.is_muted = false
	player_node.add_child(vc)

	var found: Node = pause_menu._get_local_voice_chat_manager()
	assert_eq(found, vc, "Should find VoiceChatManager via fallback loop over players children")
