extends GutTest

const COVERED: Array[String] = [
	"res://systems/round/round_manager.gd",
	"res://systems/danger/danger_manager.gd",
	"res://systems/danger/seagull_manager.gd",
	"res://systems/rocks/rock_manager.gd",
	"res://systems/zones/zone_manager.gd",
	"res://systems/quota/quota_manager.gd",
	"res://systems/quota/coin_manager.gd"
]


func test_all_covered_managers_implement_debug_contract() -> void:
	for path in COVERED:
		var script: GDScript = load(path)
		assert_not_null(script, "Failed to load script: " + path)
		if not script:
			continue

		var method_list = script.get_script_method_list()
		var method_names: Array[String] = []
		for m in method_list:
			method_names.append(m["name"])

		assert_true(method_names.has("get_debug_state"), path + " missing get_debug_state")
		assert_true(method_names.has("get_debug_actions"), path + " missing get_debug_actions")
		assert_true(method_names.has("debug_action"), path + " missing debug_action")

		var inst = script.new()
		if is_instance_valid(inst):
			autofree(inst)
			if inst.has_method("get_debug_state"):
				var st = inst.get_debug_state()
				assert_eq(typeof(st), TYPE_DICTIONARY, path + " get_debug_state() must return Dictionary")
			if inst.has_method("get_debug_actions"):
				var acts = inst.get_debug_actions()
				assert_eq(typeof(acts), TYPE_ARRAY, path + " get_debug_actions() must return Array")
				for act in acts:
					assert_eq(typeof(act), TYPE_DICTIONARY, path + " debug action must be Dictionary")
					assert_true(act.has("id"), path + " debug action missing 'id'")
					assert_eq(typeof(act["id"]), TYPE_STRING, path + " debug action 'id' must be String")
					assert_true(act.has("label"), path + " debug action missing 'label'")
					assert_eq(typeof(act["label"]), TYPE_STRING, path + " debug action 'label' must be String")


func test_debug_actions_client_noop_coverage() -> void:
	for path in COVERED:
		var script: GDScript = load(path)
		assert_not_null(script, "Failed to load script: " + path)
		if not script:
			continue

		var inst = script.new()
		if is_instance_valid(inst):
			autofree(inst)
			if inst.has_method("get_debug_actions") and inst.has_method("get_debug_state") and inst.has_method("debug_action"):
				var acts = inst.get_debug_actions()
				if not acts.is_empty():
					var action_id = acts[0]["id"]
					var state_before = inst.get_debug_state()
					var _saved_multiplayer_peer = inst.multiplayer.multiplayer_peer
					var client_peer := ENetMultiplayerPeer.new()
					client_peer.create_client("127.0.0.1", 1)
					inst.multiplayer.multiplayer_peer = client_peer

					inst.debug_action(action_id)

					var state_after = inst.get_debug_state()
					assert_eq(state_after, state_before, path + " state must remain unchanged when debug_action called on client")

					inst.multiplayer.multiplayer_peer = _saved_multiplayer_peer
