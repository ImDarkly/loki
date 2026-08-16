extends "res://world/world_setup.gd"

var which := "all"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--ws="):
			which = a.trim_prefix("--ws=")
	match which:
		"none":
			pass
		"env":
			setup_environment()
		"light":
			setup_lighting()
		"ground":
			setup_ground()
		"ground_collision":
			setup_ground_collision()
		"water":
			setup_water()
		"fps":
			_add_fps_counter()
		"all":
			setup_environment()
			setup_lighting()
			setup_ground()
			setup_ground_collision()
			setup_water()
			_add_fps_counter()
	print("PROOF[ws]: ran '", which, "'")

func _process(_delta: float) -> void:
	pass