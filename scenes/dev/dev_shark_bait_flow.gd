extends Node3D

var _coin_manager: Node3D
var _bait_manager: Node3D
var _quota_manager: Node3D
var _label: Label
var _player: Player
var _last_place_result: String = ""


func _ready() -> void:
	var local_main := get_node_or_null("main")
	if local_main:
		_coin_manager = local_main.get_node_or_null("CoinManager") as CoinManager
		_bait_manager = local_main.get_node_or_null("SharkBaitManager") as Node3D
		_quota_manager = local_main.get_node_or_null("QuotaManager") as Node3D

		if local_main.get_parent() == self:
			var root := get_tree().root
			if root.has_node("main"):
				print("DevSharkBaitFlow: /root/main already exists, keeping local main under DevSharkBaitFlow")
			else:
				remove_child(local_main)
				root.add_child(local_main)
				if root.has_node("main") and local_main.get_parent() == root:
					local_main.owner = null
				else:
					if local_main.get_parent() == null:
						add_child(local_main)
					print("DevSharkBaitFlow: Reparent main to root failed, kept locally")

	await get_tree().process_frame

	if _coin_manager == null:
		_coin_manager = _find_node_path("CoinManager") as CoinManager

	if _bait_manager == null:
		_bait_manager = _find_node_path("SharkBaitManager") as Node3D

	if _quota_manager == null:
		_quota_manager = _find_node_path("QuotaManager") as Node3D

	_label = get_node_or_null("HUD/Label") as Label
	_player = get_node_or_null("Players/Player") as Player

	if _coin_manager:
		_coin_manager.shark_bait_cost = 0
		if _bait_manager and _bait_manager.has_signal("shark_bait_placed"):
			if not _bait_manager.is_connected("shark_bait_placed", _on_bait_placed):
				_bait_manager.shark_bait_placed.connect(_on_bait_placed)

	if _label:
		_label.text = "Dev Shark Bait Flow -- C buy / P place water / I try island / O toggle owned / R reset / B +5 coins / F deposit fish"

	if _player and _bait_manager:
		pass


func _find_node_path(node_name: String) -> Node:
	var n: Node = get_node_or_null("/root/main/" + node_name)
	if n == null:
		n = get_node_or_null("main/" + node_name)
	if n == null:
		n = get_node_or_null("../main/" + node_name)
	if n == null:
		n = get_tree().root.get_node_or_null("main/" + node_name)
	if n == null:
		n = get_tree().root.find_child(node_name, true, false)
	return n


func _on_bait_placed(pos: Vector3) -> void:
	_last_place_result = "Placed at (%.1f, %.1f)" % [pos.x, pos.z]
	var notif := _find_node_path("NotificationLabel")
	if notif and notif.has_method("show_message"):
		notif.show_message("Shark Bait placed at (%.1f, %.1f)!" % [pos.x, pos.z])


func _process(_delta: float) -> void:
	if _label == null:
		return
	if _coin_manager == null:
		_coin_manager = _find_node_path("CoinManager") as CoinManager
	if _bait_manager == null:
		_bait_manager = _find_node_path("SharkBaitManager") as Node3D

	if _coin_manager == null or _bait_manager == null:
		_label.text = "Missing CoinManager or SharkBaitManager at /root/main or local main"
		return

	var owned: bool = false
	if _coin_manager.has_method("is_shark_bait_owned"):
		owned = _coin_manager.is_shark_bait_owned()
	elif "shark_bait_owned" in _coin_manager:
		owned = _coin_manager.shark_bait_owned

	var is_placed: bool = false
	var placed_pos: Vector3 = Vector3.ZERO
	var bait_fill: int = 0
	var bait_fill_cost: int = 3
	if _bait_manager:
		if "is_placed" in _bait_manager:
			is_placed = _bait_manager.is_placed
		if "placed_position" in _bait_manager:
			placed_pos = _bait_manager.placed_position
		if "bait_fill_count" in _bait_manager:
			bait_fill = _bait_manager.bait_fill_count
		if "fill_cost" in _bait_manager:
			bait_fill_cost = _bait_manager.fill_cost

	var coins: int = _coin_manager.coins if "coins" in _coin_manager else 0
	var cost: int = _coin_manager.shark_bait_cost if "shark_bait_cost" in _coin_manager else 0
	var fish: int = 0
	if _quota_manager and "shared_quota" in _quota_manager:
		fish = _quota_manager.shared_quota

	var bait_visible := false
	var bait_pos := Vector3.ZERO
	if _bait_manager and "is_placed" in _bait_manager and _bait_manager.is_placed:
		var inst = _bait_manager.get("_bait_instance")
		if is_instance_valid(inst):
			bait_visible = true
			bait_pos = inst.global_position

	var player_pos := Vector3.ZERO
	var cam_forward := Vector3.FORWARD
	if _player:
		player_pos = _player.global_position
		var cam := _player.get_node_or_null("Head/Camera3D") as Camera3D
		if cam:
			cam_forward = -cam.global_transform.basis.z

	var dist_to_center := 0.0
	if is_placed:
		dist_to_center = Vector2(placed_pos.x - MapConfig.MAP_CENTER.x, placed_pos.z - MapConfig.MAP_CENTER.z).length()
	var would_be_inside := MapConfig.is_within_radius(player_pos + cam_forward * 3.0, MapConfig.MAP_CENTER, MapConfig.ISLAND_RADIUS)

	_label.text = "Owned:%s Cost:%d Coins:%d Fish:%d | Placed:%s Fill:%d/%d %s Dist:%.1f (inside? %s)\nBaitVisible:%s BaitPos:(%.1f, %.1f, %.1f) | Player:(%.1f, %.1f, %.1f) Fwd:(%.1f, %.1f)\nLast: %s\n[C] Buy bait (0 cost)  [P] Place at camera 3m  [I] Try center (reject)  [O] Toggle owned  [R] Reset  [B] +5 coins  [G] +5 fish  [H] 1x/2x  [F] Deposit 1 fish (dev fill bar)" % [
		"yes" if owned else "no", cost, coins, fish,
		"yes" if is_placed else "no",
		bait_fill, bait_fill_cost,
		"(%.1f, %.1f)" % [placed_pos.x, placed_pos.z] if is_placed else "(none)",
		dist_to_center,
		"yes" if would_be_inside else "no",
		"yes" if bait_visible else "no",
		bait_pos.x, bait_pos.y, bait_pos.z,
		player_pos.x, player_pos.y, player_pos.z,
		cam_forward.x, cam_forward.z,
		_last_place_result
	]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_C:
				_buy_bait()
			KEY_P:
				_place_at_camera()
			KEY_I:
				_try_place_inside()
			KEY_O:
				_toggle_owned()
			KEY_R:
				_reset_all()
			KEY_B:
				_add_coins(5)
			KEY_G:
				_add_fish(5)
			KEY_F:
				_deposit_bait()
			KEY_H:
				Engine.time_scale = 1.0 if Engine.time_scale > 1.5 else 2.0
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _deposit_bait() -> void:
	if _bait_manager == null:
		return
	var is_placed: bool = _bait_manager.is_placed if "is_placed" in _bait_manager else false
	if not is_placed:
		_last_place_result = "Need bait placed first (press P)"
		return
	var fill_count: int = _bait_manager.bait_fill_count if "bait_fill_count" in _bait_manager else 0
	var fill_cost: int = _bait_manager.fill_cost if "fill_cost" in _bait_manager else 3
	if fill_count >= fill_cost:
		_last_place_result = "Bait already full (%d/%d)" % [fill_count, fill_cost]
		return
	if _player:
		_player.is_carrying = true
	if _bait_manager.has_method("request_deposit_shark_bait"):
		_bait_manager.request_deposit_shark_bait()
	await get_tree().process_frame
	var new_fill: int = _bait_manager.bait_fill_count if "bait_fill_count" in _bait_manager else 0
	var placed_pos: Vector3 = _bait_manager.placed_position if "placed_position" in _bait_manager else Vector3.ZERO
	var player_pos := _player.global_position if _player else Vector3.ZERO
	var dist := Vector2(player_pos.x - placed_pos.x, player_pos.z - placed_pos.z).length()
	if dist > 4.0:
		_last_place_result = "Too far from bait (move within 4m)"
	elif new_fill > fill_count:
		_last_place_result = "Deposited fish (Fill: %d/%d)" % [new_fill, fill_cost]
	else:
		_last_place_result = "Deposit failed"


func _buy_bait() -> void:
	if _coin_manager == null:
		return
	if _coin_manager.has_method("request_buy_shark_bait"):
		_coin_manager.request_buy_shark_bait()
		_last_place_result = "Buy attempted (cost 0 in dev)"


func _toggle_owned() -> void:
	if _coin_manager == null:
		return
	if "shark_bait_owned" in _coin_manager:
		_coin_manager.shark_bait_owned = not _coin_manager.shark_bait_owned
		if _coin_manager.has_method("_sync_shark_bait"):
			_coin_manager._sync_shark_bait.rpc(_coin_manager.shark_bait_owned)
		elif _coin_manager.has_signal("shark_bait_updated"):
			_coin_manager.shark_bait_updated.emit()
		_last_place_result = "Toggled owned -> %s" % ("yes" if _coin_manager.shark_bait_owned else "no")


func _place_at_camera() -> void:
	if _bait_manager == null or _coin_manager == null:
		return
	if not _coin_manager.is_shark_bait_owned() if _coin_manager.has_method("is_shark_bait_owned") else not _coin_manager.shark_bait_owned:
		_last_place_result = "Need owned first (press C or O)"
		return
	if _bait_manager.is_placed:
		_last_place_result = "Already placed (R to reset)"
		return
	var target := _get_camera_water_position()
	var was_placed: bool = _bait_manager.is_placed
	_bait_manager.request_place_shark_bait(target)
	await get_tree().process_frame
	if _bait_manager.is_placed and not was_placed:
		_last_place_result = "Placed at (%.1f, %.1f) OK" % [target.x, target.z]
	elif _bait_manager.is_placed:
		_last_place_result = "Already placed"
	else:
		_last_place_result = "Rejected (inside island?)"


func _try_place_inside() -> void:
	if _bait_manager == null:
		return
	var inside := MapConfig.MAP_CENTER + Vector3(MapConfig.ISLAND_RADIUS - 0.5, 0, 0)
	var was_placed: bool = _bait_manager.is_placed
	_bait_manager.request_place_shark_bait(inside)
	await get_tree().process_frame
	if _bait_manager.is_placed and not was_placed:
		_last_place_result = "Unexpected: inside accepted!"
	else:
		_last_place_result = "Inside (%.1f, %.1f) correctly rejected OK" % [inside.x, inside.z]


func _get_camera_water_position() -> Vector3:
	if _player == null:
		return MapConfig.MAP_CENTER + Vector3(MapConfig.ISLAND_RADIUS + 3.0, 0, 0)
	var cam := _player.get_node_or_null("Head/Camera3D") as Camera3D
	var origin := _player.global_position if cam == null else cam.global_position
	var dir := Vector3.FORWARD if cam == null else -cam.global_transform.basis.z
	var target := origin + dir * 3.0
	target.y = 0
	var flat := Vector2(target.x - MapConfig.MAP_CENTER.x, target.z - MapConfig.MAP_CENTER.z)
	if flat.length() <= MapConfig.ISLAND_RADIUS + 1.0:
		var outward := flat.normalized()
		if outward.length_squared() < 0.001:
			outward = Vector2(1, 0)
		target = MapConfig.MAP_CENTER + Vector3(outward.x, 0, outward.y) * (MapConfig.ISLAND_RADIUS + 1.0)
	var player_pos := _player.global_position
	var diff := Vector2(target.x - player_pos.x, target.z - player_pos.z)
	if diff.length() > 4.0:
		if diff.length_squared() > 0.001:
			var clamped_dir := diff.normalized()
			target = player_pos + Vector3(clamped_dir.x, 0, clamped_dir.y) * 3.5
		else:
			target = player_pos + Vector3(3.0, 0, 0)
	return Vector3(target.x, 0, target.z)


func _add_coins(amount: int) -> void:
	if _coin_manager == null:
		return
	_coin_manager.coins += amount
	if _coin_manager.has_method("_sync_coins"):
		_coin_manager._sync_coins.rpc(_coin_manager.coins)
	elif _coin_manager.has_signal("coins_updated"):
		_coin_manager.coins_updated.emit(_coin_manager.coins)
	_last_place_result = "+%d coins" % amount


func _add_fish(amount: int) -> void:
	if _quota_manager and "shared_quota" in _quota_manager:
		_quota_manager.shared_quota += amount
		if _quota_manager.has_signal("quota_updated"):
			_quota_manager.quota_updated.emit(_quota_manager.shared_quota)
		_last_place_result = "+%d fish" % amount


func _reset_all() -> void:
	if _bait_manager and _bait_manager.has_method("reset_for_restart"):
		_bait_manager.reset_for_restart()
	if _coin_manager:
		_coin_manager.coins = 0
		_coin_manager.shark_bait_owned = false
		if _coin_manager.has_method("_sync_coins"):
			_coin_manager._sync_coins.rpc(0)
		if _coin_manager.has_method("_sync_shark_bait"):
			_coin_manager._sync_shark_bait.rpc(false)
		_coin_manager.shark_bait_cost = 0
	if _quota_manager and "shared_quota" in _quota_manager:
		_quota_manager.shared_quota = 3
		if _quota_manager.has_signal("quota_updated"):
			_quota_manager.quota_updated.emit(_quota_manager.shared_quota)
	_last_place_result = "Reset done"
