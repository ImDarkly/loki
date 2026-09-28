extends GutTest

var lobby: CanvasLayer


func before_each() -> void:
	lobby = add_child_autofree(load("res://scenes/lobby.tscn").instantiate())
	await get_tree().process_frame


func test_validate_code_accepts_six_digits() -> void:
	lobby.code_input.text = "123456"
	assert_eq(lobby._validate_code(), "123456")


func test_validate_code_rejects_short_digits() -> void:
	lobby.code_input.text = "12345"
	assert_eq(lobby._validate_code(), "")
	assert_eq(lobby.status_label.text, "Enter a 6-digit code")


func test_validate_code_rejects_empty() -> void:
	lobby.code_input.text = ""
	assert_eq(lobby._validate_code(), "")


func test_code_input_strips_non_digits() -> void:
	lobby._on_code_text_changed("12a3")
	assert_eq(lobby.code_input.text, "123", "Letters should be filtered out of the code input")


func test_code_input_accepts_raw_digits() -> void:
	lobby.code_input.text = "987654"
	lobby._on_code_text_changed("987654")
	assert_eq(lobby.code_input.text, "987654", "Pure digits should pass through unchanged")


func test_join_failure_keeps_join_context() -> void:
	lobby.code_input.text = "123456"
	lobby._joining = true
	lobby._on_connection_failed()
	assert_true(lobby.main_menu.visible, "Main menu should stay visible")
	assert_false(lobby.lobby_view.visible, "Lobby view should stay hidden")
	assert_true(lobby.join_row.visible, "Join row should stay visible for retry")
	assert_false(lobby.join_confirm_button.disabled, "Join button should be re-enabled")
	assert_true(lobby.status_label.visible, "Status message should be visible to the joiner")
	assert_eq(lobby.status_label.text, "Couldn't connect — check the code")
	assert_eq(lobby.code_input.text, "123456", "Typed code should be preserved for retry")


func test_stale_join_flag_resets_before_host_failure() -> void:
	lobby._joining = true
	lobby._on_connection_failed()
	assert_false(lobby._joining, "Join failure should reset the join flag")
	assert_true(lobby.join_row.visible, "Join row should stay visible for retry")
	lobby._on_connection_failed()
	assert_false(lobby._joining, "Join flag stays false after host failure")
	assert_false(lobby.join_row.visible, "Join row hidden on host-side failure")
	assert_eq(lobby.status_label.text, "Connection failed")
	assert_false(lobby.create_button.disabled, "Create button should be re-enabled")


func test_candidate_pick_clears_pending_pool() -> void:
	lobby.code_input.text = "123456"
	var pool: Array[HLobby] = []
	pool.append(HLobby.new())
	lobby._pending_candidates = pool
	lobby._on_candidate_picked(0, Vector2.ZERO, 1)
	assert_true(lobby._pending_candidates.is_empty(), "Pool cleared after a pick so repeat clicks are ignored")


func test_copy_code_button_shows_feedback_without_error() -> void:
	lobby._displayed_code = "123456"
	lobby._on_copy_code_pressed()
	assert_eq(lobby.copy_code_button.text, "Copied!", "Button should show feedback immediately")


func _double_lobby_with_quit_stub(calls: Array) -> void:
	var dbl := GDScript.new()
	dbl.source_code = "extends \"res://scenes/lobby.gd\"\nvar calls: Array = []\nvar quit_saw_no_peer: bool = false\nfunc _quit_app() -> void:\n\tcalls.append(\"quit\")\n\tquit_saw_no_peer = multiplayer.multiplayer_peer == null\n"
	dbl.reload()
	lobby.set_script(dbl)
	lobby.set("calls", calls)
	var dlg := lobby.get_node_or_null("QuitDialog") as ConfirmationDialog
	if dlg and not dlg.confirmed.is_connected(Callable(lobby, "_on_quit_confirmed")):
		dlg.confirmed.connect(Callable(lobby, "_on_quit_confirmed"))


func _bind_test_peer() -> ENetMultiplayerPeer:
	var srv := ENetMultiplayerPeer.new()
	var err := srv.create_server(45732)
	assert_eq(err, OK, "test peer should bind")
	multiplayer.multiplayer_peer = srv
	return srv


func _unbind_test_peer(peer: ENetMultiplayerPeer) -> void:
	multiplayer.multiplayer_peer = null
	peer.close()


func test_quit_confirmed_disconnects_before_quit() -> void:
	var calls: Array = []
	_double_lobby_with_quit_stub(calls)
	var srv := _bind_test_peer()
	assert_not_null(multiplayer.multiplayer_peer, "test peer should be set before confirm")
	var dlg := lobby.get_node_or_null("QuitDialog") as ConfirmationDialog
	assert_not_null(dlg, "QuitDialog must exist")
	dlg.confirmed.emit()
	assert_null(multiplayer.multiplayer_peer, "Quit confirm must run disconnect_from_game (clears peer)")
	assert_eq(calls, ["quit"], "Quit must be requested via stub, never real quit")
	assert_true(lobby.get("quit_saw_no_peer"), "disconnect must run before quit")
	_unbind_test_peer(srv)


func test_quit_cancel_calls_neither() -> void:
	var calls: Array = []
	_double_lobby_with_quit_stub(calls)
	var srv := _bind_test_peer()
	lobby._on_quit_pressed()
	var dlg := lobby.get_node_or_null("QuitDialog") as ConfirmationDialog
	assert_not_null(dlg, "QuitDialog must exist")
	dlg.canceled.emit()
	assert_true(calls.is_empty(), "Canceling quit must never quit")
	assert_not_null(multiplayer.multiplayer_peer, "Canceling quit must not disconnect")
	_unbind_test_peer(srv)


func test_show_main_menu_restores_visible_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	lobby._show_main_menu()
	assert_true(lobby.main_menu.visible, "Main menu should be visible")
	assert_false(lobby.lobby_view.visible, "Lobby view should be hidden")
	if DisplayServer.get_name() != "headless":
		assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "_show_main_menu must leave mouse VISIBLE for lobby buttons")