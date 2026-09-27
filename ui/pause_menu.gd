extends CanvasLayer

@onready var resume_button: Button = $CenterPanel/VBox/ResumeButton
@onready var mute_button: Button = $CenterPanel/VBox/MuteButton
@onready var fullscreen_button: Button = $CenterPanel/VBox/FullscreenButton
@onready var exit_button: Button = $CenterPanel/VBox/ExitButton


func _ready() -> void:
	visible = false
	resume_button.pressed.connect(_on_resume_pressed)
	mute_button.pressed.connect(_on_mute_pressed)
	fullscreen_button.pressed.connect(_on_fullscreen_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	# Optionally connect round_ended (dormant for Night-phase future-proofing only)
	var rm := get_node_or_null("/root/main/RoundManager")
	if rm and rm.has_signal("round_ended"):
		rm.round_ended.connect(_on_round_ended)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			get_viewport().set_input_as_handled()
			close_menu()
		elif _can_open():
			get_viewport().set_input_as_handled()
			open_menu()


func _can_open() -> bool:
	if get_tree().root.has_node("ShopUI"):
		return false
	var end_screen := get_node_or_null("/root/main/EndScreen")
	if end_screen and end_screen.visible:
		return false
	return true


func open_menu() -> void:
	if not _can_open():
		return
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_mute_button_text()
	var gm := get_node_or_null("/root/game_manager")
	if gm:
		gm.pause_toggled.emit(true)


func close_menu() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var gm := get_node_or_null("/root/game_manager")
	if gm:
		gm.pause_toggled.emit(false)


func _on_resume_pressed() -> void:
	close_menu()


func _on_mute_pressed() -> void:
	var vc := _get_local_voice_chat_manager()
	if vc != null and vc.has_method("set_muted") and "is_muted" in vc:
		var new_muted: bool = not vc.is_muted
		vc.set_muted(new_muted)
		_update_mute_button_text()


func _get_local_voice_chat_manager() -> Node:
	var peer_id := multiplayer.get_unique_id()
	var path := "/root/main/Players/Player_%d/VoiceChatManager" % peer_id
	var manager := get_node_or_null(path)
	if manager != null:
		return manager
	var players := get_node_or_null("/root/main/Players")
	if players != null:
		for child in players.get_children():
			var vc := child.get_node_or_null("VoiceChatManager")
			if vc != null:
				return vc
	return null


func _update_mute_button_text() -> void:
	var vc := _get_local_voice_chat_manager()
	if vc != null and "is_muted" in vc:
		if vc.is_muted:
			mute_button.text = "Unmute Voice Chat"
		else:
			mute_button.text = "Mute Voice Chat"
	else:
		mute_button.text = "Mute Voice Chat"


func _on_fullscreen_pressed() -> void:
	# TODO: Implement in #279/#280
	pass


func _on_exit_pressed() -> void:
	# TODO: Implement in #279/#280
	pass


func _on_round_ended(_success: bool) -> void:
	# Dormant future-proofing stub for Night-phase
	pass
