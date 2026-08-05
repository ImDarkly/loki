extends CanvasLayer


@onready var main_menu: VBoxContainer = %MainMenu
@onready var lobby_view: VBoxContainer = %LobbyView
@onready var username_input: LineEdit = %UsernameInput
@onready var create_button: Button = %CreateButton
@onready var join_menu_button: Button = %JoinMenuButton
@onready var join_row: HBoxContainer = %JoinRow
@onready var code_input: LineEdit = %CodeInput
@onready var join_confirm_button: Button = %JoinConfirmButton
@onready var code_display: Label = %IpDisplay
@onready var code_row: HBoxContainer = %IpDisplayRow
@onready var copy_code_button: Button = %CopyIpButton
@onready var player_list: ItemList = %PlayerList
@onready var status_label: Label = %StatusLabel
@onready var start_button: Button = %StartButton

var _displayed_code: String = ""
var _pending_candidates: Array[HLobby] = []


func _ready() -> void:
	create_button.pressed.connect(_on_create_pressed)
	join_menu_button.pressed.connect(_on_join_menu_pressed)
	join_confirm_button.pressed.connect(_on_join_confirm_pressed)
	start_button.pressed.connect(_on_start_pressed)
	copy_code_button.pressed.connect(_on_copy_code_pressed)

	game_manager.player_list_changed.connect(_on_player_list_changed)
	NetworkManager.host_started.connect(_on_host_started)
	NetworkManager.connection_success.connect(_on_connection_success)
	NetworkManager.connection_failed_signal.connect(_on_connection_failed)
	NetworkManager.connection_candidates.connect(_on_connection_candidates)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	_show_main_menu()


func _show_main_menu() -> void:
	main_menu.visible = true
	lobby_view.visible = false
	join_row.visible = false
	code_row.visible = false
	start_button.visible = false
	status_label.text = ""
	player_list.clear()
	_pending_candidates = []
	if player_list.item_clicked.is_connected(_on_candidate_picked):
		player_list.item_clicked.disconnect(_on_candidate_picked)
	create_button.disabled = false
	join_menu_button.disabled = false
	join_confirm_button.disabled = false


func _show_lobby_view() -> void:
	main_menu.visible = false
	lobby_view.visible = true


func _on_create_pressed() -> void:
	var name_text := username_input.text.strip_edges()
	if name_text.is_empty():
		name_text = "Player"

	create_button.disabled = true
	join_menu_button.disabled = true
	status_label.text = "Starting server..."

	await NetworkManager.host_game()


func _on_host_started(room_code: String) -> void:
	_show_lobby_view()

	_displayed_code = room_code
	code_display.text = "Your code: " + _displayed_code
	code_row.visible = true
	start_button.visible = true
	start_button.disabled = true

	var host_name := username_input.text.strip_edges()
	if host_name.is_empty():
		host_name = "Player"
	game_manager.add_player(1, host_name)
	status_label.text = "Waiting for players..."


func _on_join_menu_pressed() -> void:
	join_row.visible = true
	code_input.grab_focus()


func _validate_code() -> String:
	var code := code_input.text.strip_edges()
	if code.is_empty() or code.length() != 6 or not code.is_valid_int():
		status_label.text = "Enter a 6-digit code"
		return ""
	return code


func _on_join_confirm_pressed() -> void:
	var code := _validate_code()
	if code.is_empty():
		return

	join_confirm_button.disabled = true
	status_label.text = "Connecting..."

	NetworkManager.join_game(code)


func _on_connection_candidates(candidates: Array[HLobby]) -> void:
	_pending_candidates = candidates
	_show_lobby_view()
	player_list.clear()
	for i in candidates.size():
		var lobby: HLobby = candidates[i]
		player_list.add_item("Lobby %d (%s)" % [i + 1, lobby.lobby_id])
	status_label.text = "Multiple lobbies found — pick one."
	start_button.visible = false
	if not player_list.item_clicked.is_connected(_on_candidate_picked):
		player_list.item_clicked.connect(_on_candidate_picked)


func _on_candidate_picked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	var code := _validate_code()
	if code.is_empty():
		return
	var candidates := _pending_candidates
	if index < 0 or index >= candidates.size():
		return
	NetworkManager.join_candidate(code, candidates[index])


func _on_connection_success() -> void:
	_show_lobby_view()
	status_label.text = "Connected to server..."
	var name_text := username_input.text.strip_edges()
	if name_text.is_empty():
		name_text = "Player"
	game_manager._submit_username.rpc_id(1, name_text)


func _on_connection_failed() -> void:
	push_error("Lobby: Connection failed")
	_show_main_menu()
	status_label.text = "Connection failed"
	create_button.disabled = false
	join_menu_button.disabled = false
	join_confirm_button.disabled = false


func _on_peer_connected(_id: int) -> void:
	if game_manager.is_server():
		start_button.disabled = game_manager.players.size() < 2
		status_label.text = "Waiting for players..."


func _on_server_disconnected() -> void:
	NetworkManager.disconnect_from_game()
	_show_main_menu()
	status_label.text = "Disconnected from server"
	start_button.disabled = true


func _on_copy_code_pressed() -> void:
	DisplayServer.clipboard_set(_displayed_code)
	copy_code_button.text = "Copied!"
	await get_tree().create_timer(2.0).timeout
	copy_code_button.text = "Copy code"


func _on_player_list_changed() -> void:
	player_list.clear()
	for p in game_manager.players:
		var label: String = p.username
		if game_manager.is_server() and p.id == game_manager.local_player_id:
			label += " (You, Host)"
		elif p.id == game_manager.local_player_id:
			label += " (You)"
		elif game_manager.is_server():
			label += " (Joined)"
		player_list.add_item(label)

	if game_manager.is_server():
		start_button.disabled = game_manager.players.size() < 2


func _on_start_pressed() -> void:
	start_button.disabled = true
	start_button.text = "Starting..."
	status_label.text = "Loading world..."
	game_manager.start_game()
