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