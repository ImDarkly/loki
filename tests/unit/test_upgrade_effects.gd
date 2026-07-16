extends GutTest

var _coin_manager
var _quota_manager
var _main


func before_each() -> void:
	_coin_manager = autofree(load("res://systems/quota/coin_manager.tscn").instantiate())
	add_child(_coin_manager)
	await get_tree().process_frame

	_main = Node3D.new()
	_main.name = "main"
	get_node("/root").add_child(_main)

	_quota_manager = load("res://systems/quota/quota_manager.tscn").instantiate()
	_quota_manager.name = "QuotaManager"
	_main.add_child(_quota_manager)
	await get_tree().process_frame


func after_each() -> void:
	if _main and is_instance_valid(_main):
		_main.queue_free()


func _create_test_player():
	var player_node = CharacterBody3D.new()

	var head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.6, 0)
	player_node.add_child(head)

	var camera = Camera3D.new()
	camera.name = "Camera3D"
	head.add_child(camera)

	var hand_left = MeshInstance3D.new()
	hand_left.name = "HandLeft"
	head.add_child(hand_left)

	var hand_right = MeshInstance3D.new()
	hand_right.name = "HandRight"
	head.add_child(hand_right)

	var body_mesh = MeshInstance3D.new()
	body_mesh.name = "BodyMesh"
	player_node.add_child(body_mesh)

	var fishing_scene = load("res://systems/fishing/fishing_mechanic.tscn")
	var fishing_mechanic = autofree(fishing_scene.instantiate())
	fishing_mechanic.name = "FishingMechanic"
	player_node.add_child(fishing_mechanic)

	var voice_chat_manager = Node.new()
	voice_chat_manager.name = "VoiceChatManager"
	voice_chat_manager.set_script(load("res://systems/voice_chat/voice_chat_manager.gd"))
	player_node.add_child(voice_chat_manager)

	var health_component = HealthComponent.new()
	health_component.name = "HealthComponent"
	player_node.add_child(health_component)

	var spectate_camera = Node3D.new()
	spectate_camera.name = "SpectateCamera"
	player_node.add_child(spectate_camera)

	var spectate_cam_camera = Camera3D.new()
	spectate_cam_camera.name = "Camera3D"
	spectate_camera.add_child(spectate_cam_camera)

	player_node.set_script(load("res://entities/player/player.gd"))

	var player = autofree(player_node)
	add_child(player)
	await get_tree().process_frame
	return player


func test_max_health_increase_applied() -> void:
	var player = await _create_test_player()
	_coin_manager.max_health_upgrade_owned = true
	_coin_manager.apply_upgrade_effects_to_player(player)

	var hp = player.get_node("HealthComponent")
	assert_eq(hp.max_health, 5 + _coin_manager.max_health_bonus,
		"max_health should increase by bonus amount")


func test_max_health_no_compound_on_reapply() -> void:
	var player = await _create_test_player()
	_coin_manager.max_health_upgrade_owned = true
	_coin_manager.apply_upgrade_effects_to_player(player)
	_coin_manager.apply_upgrade_effects_to_player(player)

	var hp = player.get_node("HealthComponent")
	assert_eq(hp.max_health, 5 + _coin_manager.max_health_bonus,
		"max_health should not compound on reapply")


func test_rise_speed_increase_applied() -> void:
	var player = await _create_test_player()
	_coin_manager.rod_pull_speed_upgrade_owned = true
	_coin_manager.apply_upgrade_effects_to_player(player)

	var fm = player.get_node("FishingMechanic")
	assert_eq(fm.player_rise_speed, 80.0 * _coin_manager.rod_pull_speed_multiplier,
		"player_rise_speed should increase by multiplier")


func test_rise_speed_no_compound_on_reapply() -> void:
	var player = await _create_test_player()
	_coin_manager.rod_pull_speed_upgrade_owned = true
	_coin_manager.apply_upgrade_effects_to_player(player)
	_coin_manager.apply_upgrade_effects_to_player(player)

	var fm = player.get_node("FishingMechanic")
	assert_eq(fm.player_rise_speed, 80.0 * _coin_manager.rod_pull_speed_multiplier,
		"player_rise_speed should not compound on reapply")
