extends GutTest

var _main
var _coin_manager
var _quota_manager
var _round_manager


func before_each() -> void:
	_main = Node3D.new()
	_main.name = "main"
	get_node("/root").add_child(_main)

	_coin_manager = autofree(load("res://systems/quota/coin_manager.tscn").instantiate())
	_coin_manager.name = "CoinManager"
	_main.add_child(_coin_manager)
	await get_tree().process_frame

	_quota_manager = load("res://systems/quota/quota_manager.tscn").instantiate()
	_quota_manager.name = "QuotaManager"
	_main.add_child(_quota_manager)

	var rm_scene = load("res://systems/round/round_manager.tscn")
	_round_manager = autofree(rm_scene.instantiate())
	add_child(_round_manager)
	_round_manager.timer.stop()
	_round_manager.round_active = true
	await get_tree().process_frame


func after_each() -> void:
	if _main and is_instance_valid(_main):
		_main.queue_free()


func test_coins_survive_restart() -> void:
	_coin_manager.coins = 42
	_round_manager._apply_restart()
	assert_eq(_coin_manager.coins, 42, "Coins should survive restart")


func test_fireplace_owned_survives_restart() -> void:
	_coin_manager.fireplace_owned = true
	_round_manager._apply_restart()
	assert_true(_coin_manager.fireplace_owned, "Fireplace ownership should survive restart")


func _water_position() -> Vector3:
	return MapConfig.MAP_CENTER + Vector3(MapConfig.ISLAND_RADIUS + 5.0, 0, 0)


func test_shark_bait_persistence_across_restart() -> void:
	_coin_manager.shark_bait_owned = true
	var shark_bait_manager = autofree(load("res://systems/shark_bait/shark_bait_manager.tscn").instantiate())
	shark_bait_manager.name = "SharkBaitManager"
	_main.add_child(shark_bait_manager)
	await get_tree().process_frame

	var water := _water_position()
	shark_bait_manager._sync_placed(water)
	shark_bait_manager._sync_fill(2)

	assert_true(_coin_manager.shark_bait_owned)
	assert_true(shark_bait_manager.is_placed)
	assert_eq(shark_bait_manager.placed_position, water)
	assert_eq(shark_bait_manager.bait_fill_count, 2)
	assert_true(is_instance_valid(shark_bait_manager._bait_instance))

	_round_manager._apply_restart()

	assert_true(_coin_manager.shark_bait_owned, "Shark bait ownership should survive restart")
	assert_true(shark_bait_manager.is_placed, "Shark bait placement should survive restart")
	assert_eq(shark_bait_manager.placed_position, water, "Shark bait position should survive restart")
	assert_eq(shark_bait_manager.bait_fill_count, 2, "Shark bait fill count should survive restart")
	assert_true(is_instance_valid(shark_bait_manager._bait_instance), "Shark bait instance should survive restart")


func test_shop_ui_close_emits_shop_toggled_false() -> void:
	var shop_scene = load("res://ui/shop_ui.tscn")
	var shop = shop_scene.instantiate()
	get_tree().root.add_child(shop)
	await get_tree().process_frame

	var gm = get_node("/root/game_manager")
	watch_signals(gm)

	_round_manager._apply_restart()

	assert_signal_emitted_with_parameters(gm, "shop_toggled", [false])


func test_fishing_mechanic_reset_on_restart() -> void:
	var player = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	_main.add_child(player)
	await get_tree().process_frame
	player.fishing_mechanic.hook_type = player.fishing_mechanic.HookType.PLAYER
	player.fishing_mechanic.current_state = player.fishing_mechanic.State.BITE

	player.fishing_mechanic.reset_for_restart()

	assert_eq(player.fishing_mechanic.hook_type, player.fishing_mechanic.HookType.NONE, "Fishing mechanic hook_type should reset to NONE on restart")
	assert_eq(player.fishing_mechanic.current_state, player.fishing_mechanic.State.IDLE, "Fishing mechanic state should reset to IDLE on restart")



