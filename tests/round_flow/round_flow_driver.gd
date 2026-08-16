extends Node

const LOBBY_SCENE := preload("res://scenes/lobby.tscn")

var role := "host"
var join_code := ""
var round_seconds := 15.0
var watchdog_seconds := 90.0
var smoke := false

var _lobby: Node
var _host_code := ""
var _started := false
var _main_ready := false
var _spawn_wait_elapsed := 0.0
var _round_shortened := false
var _reported_quota := false
var _quota_verified := false
var _night_verified := false
var _failed := false


func _ready() -> void:
	_parse_args()
	_log("role=" + role + " code=" + join_code + " round=" + str(round_seconds) + " watchdog=" + str(watchdog_seconds) + " smoke=" + str(smoke))

	_lobby = LOBBY_SCENE.instantiate()
	get_tree().root.add_child(_lobby)

	NetworkManager.host_started.connect(_on_host_started)
	NetworkManager.connection_success.connect(_on_connection_success)
	NetworkManager.connection_failed_signal.connect(func(): _log("CONNECTION_FAILED"))

	get_tree().create_timer(watchdog_seconds).timeout.connect(_watchdog)

	if role == "host":
		_log("calling _on_create_pressed")
		_lobby._on_create_pressed()
	else:
		_log("setting code and calling _on_join_confirm_pressed")
		_lobby.code_input.text = join_code
		_lobby._on_join_confirm_pressed()


func _log(msg: String) -> void:
	var f := FileAccess.open("user://round_flow_%s.log" % role, FileAccess.WRITE)
	if f:
		f.store_line(Time.get_time_string_from_system() + " " + msg)
		f.close()


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			role = a.trim_prefix("--role=")
		elif a.begins_with("--code="):
			join_code = a.trim_prefix("--code=")
		elif a.begins_with("--round="):
			round_seconds = float(a.trim_prefix("--round="))
		elif a.begins_with("--watchdog="):
			watchdog_seconds = float(a.trim_prefix("--watchdog="))
		elif a == "--smoke":
			smoke = true


func _clean_exit(code: int) -> void:
	get_tree().quit(code)


func _on_host_started(room_code: String) -> void:
	_host_code = room_code
	print("PROOF[round]: HOST_STARTED code=", _host_code)
	_log("HOST_STARTED code=" + _host_code)
	if smoke:
		print("PROOF[round]: smoke OK, quitting")
		_log("smoke OK, quitting")
		_clean_exit(0)


func _on_connection_success() -> void:
	print("PROOF[round]: CONNECTION_SUCCESS")
	_log("CONNECTION_SUCCESS")


func _process(delta: float) -> void:
	if role != "host":
		_client_process(delta)
	else:
		_host_process(delta)


func _host_process(delta: float) -> void:
	if smoke:
		return
	if _host_code.is_empty():
		return
	if not _started:
		if game_manager.players.size() >= 2:
			print("PROOF[round]: 2 players present, pressing Start")
			_started = true
			_lobby._on_start_pressed()
		return

	var main := get_node_or_null("/root/main")
	if main == null:
		return
	if not _main_ready:
		_main_ready = true
		print("PROOF[round]: main scene loaded")
		_spawn_wait_elapsed = 0.0

	if not _verify_spawns():
		_spawn_wait_elapsed += delta
		if _spawn_wait_elapsed > 10.0:
			_fail("host: missing spawned players")
		return

	if not _round_shortened:
		var rm := main.get_node_or_null("RoundManager")
		if rm:
			rm.round_duration = round_seconds
			rm.timer.stop()
			rm.timer.start(round_seconds)
			_round_shortened = true
			print("PROOF[round]: round shortened to ", round_seconds, "s")

	if not _reported_quota and _round_shortened:
		var qm := main.get_node_or_null("QuotaManager")
		if qm:
			qm.report_catch(1)
			_reported_quota = true
			print("PROOF[round]: host reported catch, quota=", qm.shared_quota)

	_check_night(main)


func _client_process(_delta: float) -> void:
	var main := get_node_or_null("/root/main")
	if main == null:
		return
	if not _main_ready:
		_main_ready = true
		print("PROOF[round]: main scene loaded (client)")
		_spawn_wait_elapsed = 0.0

	if not _verify_spawns():
		_spawn_wait_elapsed += _delta
		if _spawn_wait_elapsed > 10.0:
			_fail("client: missing spawned players")
		return

	if not _quota_verified:
		var qm := main.get_node_or_null("QuotaManager")
		if qm and qm.shared_quota >= 1:
			_quota_verified = true
			print("PROOF[round]: CLIENT_QUOTA_SYNCED quota=", qm.shared_quota)

	_check_night(main)


func _verify_spawns() -> bool:
	var players_node := get_node_or_null("/root/main/Players")
	if players_node == null:
		return false
	var names := []
	for c in players_node.get_children():
		if c.name.begins_with("Player_"):
			names.append(c.name)
	print("PROOF[round]: spawned players: ", names)
	return names.size() >= 2


func _check_night(main: Node) -> void:
	if _night_verified:
		return
	var rm := main.get_node_or_null("RoundManager")
	if rm and not rm.fishing_active:
		_night_verified = true
		print("PROOF[round]: ROUND_ENDED fishing_active=false")
		if role == "host":
			var qm := main.get_node_or_null("QuotaManager")
			print("PROOF[round]: host final quota=", qm.shared_quota if qm else "?")
		_clean_exit(0 if not _failed else 1)


func _fail(msg: String) -> void:
	_failed = true
	printerr("PROOF[round]: FAIL — ", msg)
	_clean_exit(1)


func _watchdog() -> void:
	if not _failed and not _night_verified:
		_failed = true
		printerr("PROOF[round]: WATCHDOG — flow did not complete (role=", role, ")")
	_clean_exit(1 if _failed else 0)