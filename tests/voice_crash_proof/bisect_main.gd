extends Node

const MAIN := preload("res://scenes/main.tscn")
const PLAYER_SCENE := preload("res://entities/player/player.tscn")

var spawn_without_voice := false

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var strip := []
	for a in args:
		if a.begins_with("--strip="):
			strip = a.trim_prefix("--strip=").split(",")
	print("PROOF[bisect]: stripping=[", ", ".join(strip), "]")
	var main := MAIN.instantiate()
	var no_script := args.has("noscript")
	var noprocess := args.has("noprocess")
	var noproc_only := args.has("noproc_only")
	var stubready := args.has("stubready")
	var novoice := args.has("novoice")
	spawn_without_voice = novoice
	var ws_select := ""
	for a in args:
		if a.begins_with("--ws="):
			ws_select = a.trim_prefix("--ws=")
	if no_script:
		main.set_script(null)
	elif ws_select != "":
		var ws := load("res://tests/voice_crash_proof/ws_select.gd") as GDScript
		main.set_script(ws)
		main.set("which", ws_select)
	elif stubready:
		var stub := GDScript.new()
		stub.source_code = "extends Node3D\nfunc _ready():\n\tpass\nfunc _process(delta):\n\tpass\n"
		stub.reload()
		main.set_script(stub)
	elif noprocess:
		var stub := GDScript.new()
		stub.source_code = "extends Node3D\nfunc _process(delta):\n\tpass\n"
		stub.reload()
		main.set_script(stub)
	for c in main.get_children():
		if c.name in strip:
			main.remove_child(c)
			c.free()
	call_deferred("add_child", main)
	if noproc_only:
		get_tree().create_timer(0.2).timeout.connect(func(): main.set_process(false))
	if args.has("noenvironment"):
		get_tree().create_timer(0.3).timeout.connect(func(): _strip_env_nodes(main))
	get_tree().create_timer(1.0).timeout.connect(_add_and_spawn)
	get_tree().create_timer(30.0).timeout.connect(_watchdog)

func _strip_env_nodes(main: Node) -> void:
	for c in main.get_children():
		if c.name in ["WorldEnvironment", "DirectionalLight3D", "FPSLayer"]:
			main.remove_child(c)
			c.queue_free()
	# ground + water are MeshInstance3D (unnamed); remove all MeshInstance3D/StaticBody3D directly under main
	for c in main.get_children():
		if c is MeshInstance3D or c is StaticBody3D:
			main.remove_child(c)
			c.queue_free()
	print("PROOF[bisect]: stripped world nodes")

func _add_and_spawn() -> void:
	game_manager.add_player(1, "Host")
	print("PROOF[bisect]: spawning 1 player")
	if spawn_without_voice:
		var player := PLAYER_SCENE.instantiate() as Player
		var vc := player.get_node_or_null("VoiceChatNetwork")
		if vc:
			player.remove_child(vc)
			vc.queue_free()
		var spawner: Node = game_manager.spawn_manager.spawner
		player.name = "Player_1"
		player.spawn_index = 0
		spawner.add_child(player, true)
		print("PROOF[bisect]: spawned player without VoiceChatNetwork")
	else:
		game_manager.spawn_manager.trigger_spawn()

func _watchdog() -> void:
	print("PROOF[bisect]: 30s watchdog, quitting")
	get_tree().quit()