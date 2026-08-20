extends GutTest

var fireplace: StaticBody3D
var coin_manager: CoinManager
var _main: Node3D


func before_each() -> void:
	_main = Node3D.new()
	_main.name = "main"
	get_node("/root").add_child(_main)

	coin_manager = load("res://systems/quota/coin_manager.tscn").instantiate()
	coin_manager.name = "CoinManager"
	_main.add_child(coin_manager)

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