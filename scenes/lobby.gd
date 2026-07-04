extends CanvasLayer


@onready var main_menu: VBoxContainer = %MainMenu
@onready var lobby_view: VBoxContainer = %LobbyView
@onready var create_button: Button = %CreateButton
@onready var join_menu_button: Button = %JoinMenuButton
@onready var join_row: HBoxContainer = %JoinRow
@onready var join_code_input: LineEdit = %JoinCodeInput
@onready var join_confirm_button: Button = %JoinConfirmButton
@onready var join_code_display: Label = %JoinCodeDisplay
@onready var join_code_row: HBoxContainer = %JoinCodeRow
@onready var copy_code_button: Button = %CopyCodeButton
@onready var player_list: ItemList = %PlayerList
@onready var status_label: Label = %StatusLabel
@onready var start_button: Button = %StartButton

var _lobby_code: String = ""

func _ready() -> void:
	create_button.pressed.connect(_on_create_pressed)
	join_menu_button.pressed.connect(_on_join_menu_pressed)
	join_confirm_button.pressed.connect(_on_join_confirm_pressed)
	start_button.pressed.connect(_on_start_pressed)
	copy_code_button.pressed.connect(_on_copy_code_pressed)

	game_manager.player_list_changed.connect(_on_player_list_changed)
	GDSync.lobby_created.connect(_on_lobby_created)
	GDSync.lobby_creation_failed.connect(_on_lobby_creation_failed)
	GDSync.lobby_joined.connect(_on_lobby_joined)
	GDSync.lobby_join_failed.connect(_on_lobby_join_failed)
	GDSync.change_scene_called.connect(_on_change_scene_called)
	GDSync.connected.connect(_on_connected)
	GDSync.connection_failed.connect(_on_connection_failed)

	_show_main_menu()
	_set_connecting_state(true)


func _set_connecting_state(connecting: bool) -> void:
	create_button.disabled = connecting
	join_menu_button.disabled = connecting
	join_confirm_button.disabled = connecting
	status_label.text = "Connecting..." if connecting else ""


func _on_connected() -> void:
	_set_connecting_state(false)


func _on_connection_failed(error: int) -> void:
	push_error("Lobby: Connection failed: ", error)
	status_label.text = "Connection failed. Restart to retry."


func _on_copy_code_pressed() -> void:
	DisplayServer.clipboard_set(_lobby_code)
	copy_code_button.text = "Copied!"
	await get_tree().create_timer(2.0).timeout
	copy_code_button.text = "Copy"


func _show_main_menu() -> void:
	main_menu.visible = true
	lobby_view.visible = false
	join_code_row.visible = false
	start_button.visible = false
	status_label.text = ""
	player_list.clear()


func _on_create_pressed() -> void:
	var chars := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
	var lobby_name := ""
	for i in range(6):
		lobby_name += chars[randi() % chars.length()]

	create_button.disabled = true
	join_menu_button.disabled = true
	status_label.text = "Creating lobby..."

	GDSync.lobby_create(lobby_name, "", false, 4)


func _on_lobby_created(lobby_name: String) -> void:
	status_label.text = "Joining lobby..."
	GDSync.lobby_join(lobby_name, "")


func _on_lobby_creation_failed(_lobby_name: String, error: int) -> void:
	create_button.disabled = false
	join_menu_button.disabled = false

	match error:
		ENUMS.LOBBY_CREATION_ERROR.LOBBY_ALREADY_EXISTS:
			_on_create_pressed()
		_:
			status_label.text = "Failed to create lobby"


func _on_lobby_joined(lobby_name: String) -> void:
	main_menu.visible = false
	lobby_view.visible = true
	create_button.disabled = false
	join_menu_button.disabled = false
	join_row.visible = false
	join_code_input.text = ""

	_lobby_code = lobby_name
	join_code_display.text = "Join Code: " + lobby_name
	join_code_row.visible = game_manager.is_host()
	start_button.visible = game_manager.is_host()

	_on_player_list_changed()


func _on_lobby_join_failed(_lobby_name: String, _error: int) -> void:
	create_button.disabled = false
	join_menu_button.disabled = false
	join_confirm_button.disabled = false
	status_label.text = "Failed to join lobby"


func _on_join_menu_pressed() -> void:
	join_row.visible = true
	join_code_input.grab_focus()


func _on_join_confirm_pressed() -> void:
	var code := join_code_input.text.strip_edges().to_upper()
	if code.is_empty():
		status_label.text = "Enter a join code"
		return

	join_confirm_button.disabled = true
	status_label.text = "Joining..."

	GDSync.lobby_join(code, "")


func _on_player_list_changed() -> void:
	player_list.clear()
	for p in game_manager.players:
		var label: String = p.username
		if game_manager.is_host() and p.id == game_manager.local_player_id:
			label += " (You, Host)"
		elif p.id == game_manager.local_player_id:
			label += " (You)"
		elif game_manager.is_host():
			label += " (Joined)"
		player_list.add_item(label)


func _on_start_pressed() -> void:
	start_button.disabled = true
	start_button.text = "Starting..."
	GDSync.lobby_set_data("open", false)
	game_manager.start_game()


func _on_change_scene_called(_scene_path: String) -> void:
	status_label.text = "Loading world..."
