extends CanvasLayer


@onready var main_menu: VBoxContainer = %MainMenu
@onready var lobby_view: VBoxContainer = %LobbyView
@onready var username_input: LineEdit = %UsernameInput
@onready var create_button: Button = %CreateButton
@onready var join_menu_button: Button = %JoinMenuButton
@onready var join_row: HBoxContainer = %JoinRow
@onready var ip_input: LineEdit = %IpInput
@onready var port_input: SpinBox = %PortInput
@onready var join_confirm_button: Button = %JoinConfirmButton
@onready var ip_display: Label = %IpDisplay
@onready var ip_display_row: HBoxContainer = %IpDisplayRow
@onready var copy_ip_button: Button = %CopyIpButton
@onready var player_list: ItemList = %PlayerList
@onready var status_label: Label = %StatusLabel
@onready var start_button: Button = %StartButton

var _displayed_ip: String = ""


func _ready() -> void:
	create_button.pressed.connect(_on_create_pressed)
	join_menu_button.pressed.connect(_on_join_menu_pressed)
	join_confirm_button.pressed.connect(_on_join_confirm_pressed)
	start_button.pressed.connect(_on_start_pressed)
	copy_ip_button.pressed.connect(_on_copy_ip_pressed)

	game_manager.player_list_changed.connect(_on_player_list_changed)
	NetworkManager.host_started.connect(_on_host_started)
	NetworkManager.connection_success.connect(_on_connection_success)
	NetworkManager.connection_failed_signal.connect(_on_connection_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	_show_main_menu()


func _show_main_menu() -> void:
	main_menu.visible = true
	lobby_view.visible = false
	join_row.visible = false
	ip_display_row.visible = false
	start_button.visible = false
	status_label.text = ""
	player_list.clear()
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

	NetworkManager.host_game(int(port_input.value))


func _on_host_started(ip: String) -> void:
	_show_lobby_view()

	var public_ip := NetworkManager.public_ip
	_displayed_ip = public_ip if not public_ip.is_empty() else ip
	ip_display.text = "Your IP: " + _displayed_ip
	ip_display_row.visible = true
	start_button.visible = true
	start_button.disabled = true

	var host_name := username_input.text.strip_edges()
	if host_name.is_empty():
		host_name = "Player"
	game_manager.add_player(1, host_name)
	status_label.text = "Waiting for players..."


func _on_join_menu_pressed() -> void:
	join_row.visible = true
	ip_input.grab_focus()


func _on_join_confirm_pressed() -> void:
	var ip := ip_input.text.strip_edges()
	if ip.is_empty():
		status_label.text = "Enter host IP"
		return
	var port := int(port_input.value)

	join_confirm_button.disabled = true
	status_label.text = "Connecting..."

	NetworkManager.join_game(ip, port)


func _on_connection_success() -> void:
	_show_lobby_view()
	status_label.text = "Connected to server..."
	var name_text := username_input.text.strip_edges()
	if name_text.is_empty():
		name_text = "Player"
	game_manager._submit_username.rpc_id(1, name_text)


func _on_connection_failed() -> void:
	push_error("Lobby: Connection failed")
	status_label.text = "Connection failed"
	create_button.disabled = false
	join_menu_button.disabled = false
	join_confirm_button.disabled = false


func _on_peer_connected(_id: int) -> void:
	if game_manager.is_host():
		start_button.disabled = game_manager.players.size() < 2
		status_label.text = "Waiting for players..."


func _on_server_disconnected() -> void:
	NetworkManager.disconnect_from_game()
	_show_main_menu()
	status_label.text = "Disconnected from server"
	start_button.disabled = true


func _on_copy_ip_pressed() -> void:
	DisplayServer.clipboard_set(_displayed_ip)
	copy_ip_button.text = "Copied!"
	await get_tree().create_timer(2.0).timeout
	copy_ip_button.text = "Copy IP"


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

	if game_manager.is_host():
		start_button.disabled = game_manager.players.size() < 2


func _on_start_pressed() -> void:
	start_button.disabled = true
	start_button.text = "Starting..."
	status_label.text = "Loading world..."
	game_manager.start_game()
