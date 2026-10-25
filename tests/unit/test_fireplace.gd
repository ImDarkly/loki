extends GutTest

var fireplace: StaticBody3D
var coin_manager: CoinManager
var _main: Node3D
var _saved_peer: MultiplayerPeer


func before_each() -> void:
	_saved_peer = multiplayer.multiplayer_peer
	_main = Node3D.new()
	_main.name = "main"
	get_node("/root").add_child(_main)

	coin_manager = load("res://systems/quota/coin_manager.tscn").instantiate()
	coin_manager.name = "CoinManager"
	_main.add_child(coin_manager)

	var notif: Node = autofree(load("res://ui/notification_label.tscn").instantiate())
	notif.name = "NotificationLabel"
	_main.add_child(notif)

	fireplace = load("res://entities/fireplace.tscn").instantiate()
	add_child(fireplace)
	await get_tree().process_frame


func after_each() -> void:
	if fireplace and is_instance_valid(fireplace):
		fireplace.free()
	fireplace = null
	if _main and is_instance_valid(_main):
		_main.free()
	_main = null
	multiplayer.multiplayer_peer = _saved_peer


func _build_player(node_name: String) -> Player:
	var player := (load("res://entities/player/player.tscn") as PackedScene).instantiate()
	player.name = node_name
	add_child(player)
	await get_tree().process_frame
	return player as Player


func test_prompt_disabled_before_purchase() -> void:
	coin_manager.fireplace_owned = false
	fireplace._update_prompt()
	assert_false(fireplace.get_node("InteractableComponent").is_enabled,
		"Interactable should be disabled before purchase")


func test_prompt_enabled_after_purchase() -> void:
	coin_manager.fireplace_owned = true
	fireplace._update_prompt()
	var ic = fireplace.get_node("InteractableComponent")
	assert_true(ic.is_enabled, "Interactable should be enabled after purchase")
	assert_string_contains(ic.prompt_text, "Sit", "Prompt should invite sitting")


func test_interact_before_purchase_does_not_sit() -> void:
	coin_manager.fireplace_owned = false
	var player := await _build_player("Player_1")
	fireplace.get_node("InteractableComponent").interacted.emit(player)
	assert_false(player._sitting_heal.is_sitting, "No sitting before purchase")
	player.free()


func test_interact_after_purchase_toggles_sitting() -> void:
	coin_manager.fireplace_owned = true
	var player := await _build_player("Player_1")
	fireplace.get_node("InteractableComponent").interacted.emit(player)
	assert_true(player._sitting_heal.is_sitting, "Right-click should sit on owned fireplace")
	fireplace.get_node("InteractableComponent").interacted.emit(player)
	assert_false(player._sitting_heal.is_sitting, "Second right-click should stand up")
	player.free()


func test_flames_hidden_before_purchase() -> void:
	assert_false(fireplace.get_node("FlameLow").visible, "Flames should be hidden before purchase")
	assert_false(fireplace.get_node("FlameMid").visible, "Flames should be hidden before purchase")
	assert_false(fireplace.get_node("FlameTip").visible, "Flames should be hidden before purchase")


func test_flames_visible_after_purchase() -> void:
	coin_manager.fireplace_owned = true
	coin_manager.fireplace_updated.emit()
	assert_true(fireplace.get_node("FlameLow").visible, "Flames should burn after purchase")
	assert_true(fireplace.get_node("FlameMid").visible, "Flames should burn after purchase")
	assert_true(fireplace.get_node("FlameTip").visible, "Flames should burn after purchase")


func test_purchase_shows_notification() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	coin_manager.coins = 20
	coin_manager.request_buy_fireplace()
	var label := _main.get_node("NotificationLabel/Label") as Label
	assert_string_contains(label.text, "bought the Fireplace", "Purchase should notify the team")


func test_seats_hidden_before_purchase() -> void:
	assert_false(fireplace.get_node("Seats").visible, "Seats should be hidden before purchase")


func test_seats_visible_after_purchase() -> void:
	coin_manager.fireplace_owned = true
	coin_manager.fireplace_updated.emit()
	assert_true(fireplace.get_node("Seats").visible, "Seats should be visible after purchase")


func test_interact_assigns_seat_and_snaps_position() -> void:
	coin_manager.fireplace_owned = true
	var player := await _build_player("Player_1")
	fireplace.get_node("InteractableComponent").interacted.emit(player)
	assert_not_null(player.assigned_fireplace_seat, "Player should be assigned to a seat")
	var seat_pos = (player.assigned_fireplace_seat as Node3D).global_position
	assert_eq(player.global_position, seat_pos, "Player position should snap to the seat position")
	player.free()


func test_fireplace_has_world_label_hint() -> void:
	var hint = fireplace.get_node_or_null("WorldLabelHint") as WorldLabelHint
	assert_not_null(hint, "Fireplace should have WorldLabelHint")
	assert_eq(hint.label_text, "Fireplace")


func test_sourced_pit_remains_visible_across_purchase() -> void:
	assert_null(fireplace.get_node_or_null("StoneRing"), "Primitive ring should be replaced by the sourced pit")
	var visual := fireplace.get_node_or_null("Mesh") as Node3D
	assert_not_null(visual)
	if not visual:
		return
	assert_true(visual.visible)
	coin_manager.fireplace_owned = true
	coin_manager.fireplace_updated.emit()
	assert_true(visual.visible, "Purchase should only toggle flames and seats")
	assert_almost_eq(fireplace.get_node("CollisionShape3D").shape.radius, 1.1, 0.001)
	assert_almost_eq(fireplace.get_node("CollisionShape3D").shape.height, 0.8, 0.001)
	assert_eq(fireplace.get_node("Seats/Seat1").position, Vector3(0, 0, 1.8))
	if ResourceLoader.exists("res://entities/fireplace/assets/kenney_survival/campfire-pit.glb"):
		assert_gt(visual.find_children("*", "MeshInstance3D", true, false).size(), 0, "Installed pit should render")


func test_smaller_flames_preserve_stools_and_interaction_anchors() -> void:
	assert_eq(fireplace.get_node("CollisionShape3D").position, Vector3(0, 0.4, 0))
	assert_eq(fireplace.get_node("WorldLabelHint").position, Vector3(0, 0.6, 0))
	assert_eq(fireplace.get_node("Seats").transform, Transform3D.IDENTITY)
	for flame_name in ["FlameLow", "FlameMid", "FlameTip"]:
		var flame := fireplace.get_node(flame_name) as MeshInstance3D
		var bounds: AABB = flame.transform * flame.mesh.get_aabb()
		assert_gt(bounds.position.y, 0.0)
		assert_lt(bounds.end.y, 0.5, "Flame should stay below the smaller fire's height limit")
		assert_gt(bounds.size.y, 0.07, "Flame should retain a visible volume")
	var seat_positions := [Vector3(0, 0, 1.8), Vector3(0, 0, -1.8), Vector3(1.8, 0, 0), Vector3(-1.8, 0, 0)]
	for i in range(4):
		var seat := fireplace.get_node("Seats/Seat%d" % (i + 1)) as Node3D
		assert_eq(seat.position, seat_positions[i])
		assert_almost_eq(seat.scale, Vector3.ONE, Vector3.ONE * 0.001)
		var stool := seat.get_node("Stool") as MeshInstance3D
		assert_almost_eq(stool.scale, Vector3.ONE * 0.4875, Vector3.ONE * 0.000001, "Stool scale stays unchanged")
		assert_almost_eq(stool.position, Vector3(0, 0.0609375, 0), Vector3.ONE * 0.000001, "Stool position stays unchanged")
		assert_eq(stool.rotation, Vector3.ZERO, "Stool rotation stays unchanged")
		var bounds: AABB = stool.transform * stool.mesh.get_aabb()
		assert_almost_eq(bounds.position.y, 0.0, 0.001, "Stool base stays grounded")
		assert_gt(bounds.size.x, 0.3)
		assert_lt(bounds.size.x, 0.4, "Stool retains its approved width")


func test_sourced_pit_has_smaller_footprint() -> void:
	if not ResourceLoader.exists("res://entities/fireplace/assets/kenney_survival/campfire-pit.glb"):
		pending("Install and import the sourced pit to check its smaller footprint")
		return
	var visuals := fireplace.get_node("Mesh").find_children("*", "MeshInstance3D", true, false)
	assert_gt(visuals.size(), 0)
	if visuals.is_empty():
		return
	var first := visuals[0] as MeshInstance3D
	var bounds: AABB = first.global_transform * first.mesh.get_aabb()
	for visual: MeshInstance3D in visuals:
		bounds = bounds.merge(visual.global_transform * visual.mesh.get_aabb())
	assert_gt(bounds.size.x, 0.75, "Pit should retain a readable footprint")
	assert_gt(bounds.size.z, 0.75)
	assert_lt(bounds.size.x, 0.85, "Pit should stay within the smaller footprint")
	assert_lt(bounds.size.z, 0.85)


func test_primitive_base_stays_until_campfire_pit_is_loaded() -> void:
	var fire := autofree(load("res://entities/fireplace.tscn").instantiate()) as StaticBody3D
	var fallback := fire.get_node_or_null("Mesh/Fallback") as Node3D
	assert_not_null(fallback, "Packed scene should provide the base before optional assets load")
	if fallback == null:
		return
	assert_eq(fallback.find_children("*", "MeshInstance3D", true, false).size(), 4)
	assert_eq(fallback.get_node("StoneRing").position, Vector3(0, 0.2, 0))
	assert_eq(fallback.get_node("Pit").position, Vector3(0, 0.35, 0))
	add_child(fire)
	await get_tree().process_frame
	if fire.has_node("Mesh/CampfirePit"):
		assert_null(fire.get_node_or_null("Mesh/Fallback"), "Successful pit replaces the primitive base immediately")
	else:
		for mesh: MeshInstance3D in fallback.find_children("*", "MeshInstance3D", true, false):
			assert_true(mesh.is_visible_in_tree(), "Failed pit load keeps the base visible before purchase")
