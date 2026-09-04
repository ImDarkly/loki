extends GutTest

var coin_manager: CoinManager
var quota_manager: Node3D


func before_each() -> void:
	coin_manager = autofree(load("res://systems/quota/coin_manager.tscn").instantiate())
	add_child(coin_manager)
	await get_tree().process_frame

	var main = Node3D.new()
	main.name = "main"
	get_node("/root").add_child(main)

	quota_manager = load("res://systems/quota/quota_manager.tscn").instantiate()
	quota_manager.name = "QuotaManager"
	main.add_child(quota_manager)
	await get_tree().process_frame


func after_each() -> void:
	var main = get_node_or_null("/root/main")
	if main:
		main.queue_free()


func test_sell_all_converts_fish_to_coins() -> void:
	quota_manager.shared_quota = 5
	coin_manager.request_sell_all()
	assert_eq(coin_manager.coins, 5, "Coins should equal fish count * coins_per_fish")
	assert_eq(quota_manager.shared_quota, 0, "Shared quota should be zero after sell")


func test_sell_all_with_zero_fish_does_nothing() -> void:
	quota_manager.shared_quota = 0
	coin_manager.request_sell_all()
	assert_eq(coin_manager.coins, 0, "Coins should remain 0 when no fish to sell")


func test_sell_all_multiplies_by_coins_per_fish() -> void:
	coin_manager.coins_per_fish = 3
	quota_manager.shared_quota = 4
	coin_manager.request_sell_all()
	assert_eq(coin_manager.coins, 12, "Coins should equal fish * coins_per_fish")


func test_sell_all_emits_coins_updated() -> void:
	quota_manager.shared_quota = 3
	watch_signals(coin_manager)
	coin_manager.request_sell_all()
	assert_signal_emitted(coin_manager, "coins_updated")


func test_buy_fireplace_deducts_coins_and_marks_owned() -> void:
	coin_manager.coins = 20
	coin_manager.request_buy_fireplace()
	assert_eq(coin_manager.coins, 5, "Coins should be reduced by fireplace cost (15)")
	assert_true(coin_manager.is_fireplace_owned(), "Fireplace should be owned after purchase")


func test_buy_fireplace_prevents_second_purchase() -> void:
	coin_manager.coins = 50
	coin_manager.request_buy_fireplace()
	coin_manager.request_buy_fireplace()
	assert_eq(coin_manager.coins, 35, "Coins should only be deducted once")
	assert_true(coin_manager.is_fireplace_owned(), "Fireplace should remain owned")


func test_buy_fireplace_insufficient_coins_does_nothing() -> void:
	coin_manager.coins = 5
	coin_manager.request_buy_fireplace()
	assert_eq(coin_manager.coins, 5, "Coins should not change when buy fails")
	assert_false(coin_manager.is_fireplace_owned(), "Fireplace should not be owned")


func test_buy_fireplace_emits_signals() -> void:
	coin_manager.coins = 20
	watch_signals(coin_manager)
	coin_manager.request_buy_fireplace()
	assert_signal_emitted(coin_manager, "coins_updated")
	assert_signal_emitted(coin_manager, "fireplace_updated")


func test_buy_shark_bait_deducts_coins_and_marks_owned() -> void:
	coin_manager.coins = 20
	coin_manager.request_buy_shark_bait()
	assert_eq(coin_manager.coins, 5, "Coins should be reduced by shark bait cost (15)")
	assert_true(coin_manager.is_shark_bait_owned(), "Shark Bait should be owned after purchase")


func test_buy_shark_bait_prevents_second_purchase() -> void:
	coin_manager.coins = 50
	coin_manager.request_buy_shark_bait()
	coin_manager.request_buy_shark_bait()
	assert_eq(coin_manager.coins, 35, "Coins should only be deducted once")
	assert_true(coin_manager.is_shark_bait_owned(), "Shark Bait should remain owned")


func test_buy_shark_bait_insufficient_coins_does_nothing() -> void:
	coin_manager.coins = 5
	coin_manager.request_buy_shark_bait()
	assert_eq(coin_manager.coins, 5, "Coins should not change when buy fails")
	assert_false(coin_manager.is_shark_bait_owned(), "Shark Bait should not be owned")


func test_buy_shark_bait_emits_signals() -> void:
	coin_manager.coins = 20
	watch_signals(coin_manager)
	coin_manager.request_buy_shark_bait()
	assert_signal_emitted(coin_manager, "coins_updated")
	assert_signal_emitted(coin_manager, "shark_bait_updated")


func test_request_buy_item_fireplace() -> void:
	coin_manager.coins = 20
	watch_signals(coin_manager)
	coin_manager.request_buy_item(&"fireplace")
	assert_eq(coin_manager.coins, 5)
	assert_true(coin_manager.is_fireplace_owned())
	assert_signal_emitted(coin_manager, "coins_updated")
	assert_signal_emitted(coin_manager, "fireplace_updated")
	assert_signal_not_emitted(coin_manager, "shark_bait_updated")


func test_request_buy_item_shark_bait() -> void:
	coin_manager.coins = 20
	watch_signals(coin_manager)
	coin_manager.request_buy_item(&"shark_bait")
	assert_eq(coin_manager.coins, 5)
	assert_true(coin_manager.is_shark_bait_owned())
	assert_signal_emitted(coin_manager, "coins_updated")
	assert_signal_emitted(coin_manager, "shark_bait_updated")
	assert_signal_not_emitted(coin_manager, "fireplace_updated")


func test_request_buy_item_second_purchase_prevented() -> void:
	coin_manager.coins = 50
	coin_manager.request_buy_item(&"fireplace")
	coin_manager.request_buy_item(&"fireplace")
	assert_eq(coin_manager.coins, 35, "Coins should only be deducted once for fireplace")
	coin_manager.request_buy_item(&"shark_bait")
	coin_manager.request_buy_item(&"shark_bait")
	assert_eq(coin_manager.coins, 20, "Coins should only be deducted once for shark bait")


func test_request_buy_item_insufficient_coins_no_op() -> void:
	coin_manager.coins = 5
	coin_manager.request_buy_item(&"fireplace")
	assert_eq(coin_manager.coins, 5)
	assert_false(coin_manager.is_fireplace_owned())
	coin_manager.request_buy_item(&"shark_bait")
	assert_eq(coin_manager.coins, 5)
	assert_false(coin_manager.is_shark_bait_owned())


func test_request_buy_item_invalid_id() -> void:
	coin_manager.coins = 50
	coin_manager.request_buy_item(&"invalid_item")
	assert_eq(coin_manager.coins, 50)


func test_get_debug_state_keys_and_types() -> void:
	var st = coin_manager.get_debug_state()
	assert_true(st.has("coins"))
	assert_true(st.has("fireplace_owned"))
	assert_true(st.has("shark_bait_owned"))
	assert_eq(typeof(st["coins"]), TYPE_INT)
	assert_eq(typeof(st["fireplace_owned"]), TYPE_BOOL)
	assert_eq(typeof(st["shark_bait_owned"]), TYPE_BOOL)


func test_get_debug_actions_ids_and_labels() -> void:
	var acts = coin_manager.get_debug_actions()
	assert_eq(acts.size(), 4)
	var map = {}
	for act in acts:
		map[act["id"]] = act["label"]
	assert_eq(map.get("add_coins_10"), "+10 Coins")
	assert_eq(map.get("remove_coins_10"), "-10 Coins")
	assert_eq(map.get("toggle_fireplace"), "Toggle Fireplace")
	assert_eq(map.get("toggle_shark_bait"), "Toggle Shark Bait")


func test_debug_actions_execution() -> void:
	coin_manager.coins = 5
	coin_manager.debug_action("add_coins_10")
	assert_eq(coin_manager.coins, 15)

	coin_manager.debug_action("remove_coins_10")
	assert_eq(coin_manager.coins, 5)

	assert_false(coin_manager.is_fireplace_owned())
	coin_manager.debug_action("toggle_fireplace")
	assert_true(coin_manager.is_fireplace_owned())

	assert_false(coin_manager.is_shark_bait_owned())
	coin_manager.debug_action("toggle_shark_bait")
	assert_true(coin_manager.is_shark_bait_owned())


func test_debug_action_client_noop() -> void:
	coin_manager.coins = 5
	var peer := ENetMultiplayerPeer.new()
	peer.create_client("127.0.0.1", 1)
	coin_manager.multiplayer.multiplayer_peer = peer
	coin_manager.debug_action("add_coins_10")
	assert_eq(coin_manager.coins, 5, "Client should no-op debug_action")
	coin_manager.multiplayer.multiplayer_peer = null


func test_coin_manager_registers_with_debug_overlay() -> void:
	var dbg = get_node_or_null("/root/DebugOverlay")
	assert_not_null(dbg, "DebugOverlay autoload missing")
	assert_true(dbg._systems.has(coin_manager.name), "CoinManager should register with DebugOverlay")
