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


func test_upgrade_flags_survive_restart() -> void:
	_coin_manager.max_health_upgrade_owned = true
	_coin_manager.rod_pull_speed_upgrade_owned = true
	_round_manager._apply_restart()
	assert_true(_coin_manager.max_health_upgrade_owned, "max_health flag should survive restart")
	assert_true(_coin_manager.rod_pull_speed_upgrade_owned, "rod_pull_speed flag should survive restart")


func test_shop_ui_close_emits_shop_toggled_false() -> void:
	var shop_scene = load("res://ui/shop_ui.tscn")
	var shop = shop_scene.instantiate()
	get_tree().root.add_child(shop)
	await get_tree().process_frame

	var gm = get_node("/root/game_manager")
	watch_signals(gm)

	_round_manager._apply_restart()

	assert_signal_emitted_with_parameters(gm, "shop_toggled", [false])
