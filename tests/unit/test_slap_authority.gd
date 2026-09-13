extends GutTest

var _players_container: Node3D
var _attacker: Player
var _target: Player
var _attacker_comp: SlapComponent
var _target_comp: SlapComponent


func before_each() -> void:
	_players_container = autofree(Node3D.new())
	_players_container.name = "Players"
	add_child(_players_container)

	_attacker = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	_attacker.name = "Player_1"
	_players_container.add_child(_attacker)
	_attacker.global_position = Vector3(0, 0, 0)
	_attacker_comp = _attacker._slap_component

	_target = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	_target.name = "Player_2"
	_players_container.add_child(_target)
	_target.global_position = Vector3(0, 0, -1.5)
	_target_comp = _target._slap_component


func after_each() -> void:
	if _players_container and is_instance_valid(_players_container):
		_players_container.free()


func test_valid_slap_applies_and_sets_cooldown() -> void:
	_attacker.start_carrying()
	assert_true(_attacker.is_carrying)
	assert_false(_target.is_slapped)

	_attacker_comp.request_slap(2)

	assert_true(_target.is_slapped, "Target should be slapped on valid request")
	assert_gt(_attacker_comp._slap_cooldown_left, 0.0, "Attacker cooldown should be set")


func test_invalid_target_missing() -> void:
	_attacker.start_carrying()
	_attacker_comp.request_slap(999)
	assert_false(_target.is_slapped)


func test_invalid_target_not_alive() -> void:
	_attacker.start_carrying()
	_target.player_state = Player.PlayerState.SPECTATE
	_attacker_comp.request_slap(2)
	assert_false(_target.is_slapped)


func test_invalid_target_already_slapped() -> void:
	_attacker.start_carrying()
	_target_comp.apply_slap(3.5)
	assert_true(_target.is_slapped)
	_attacker_comp.request_slap(2)
	assert_true(_target.is_slapped)


func test_invalid_self_hit() -> void:
	_attacker.start_carrying()
	_attacker_comp.request_slap(1)
	assert_false(_attacker.is_slapped)


func test_invalid_attacker_not_carrying() -> void:
	assert_false(_attacker.is_carrying)
	_attacker_comp.request_slap(2)
	assert_false(_target.is_slapped)


func test_invalid_attacker_holding_rock() -> void:
	_attacker.start_carrying()
	_attacker.holding_rock = true
	_attacker_comp.request_slap(2)
	assert_false(_target.is_slapped)


func test_invalid_attacker_holding_bait() -> void:
	_attacker.start_carrying()
	_attacker.holding_shark_bait = true
	_attacker_comp.request_slap(2)
	assert_false(_target.is_slapped)


func test_invalid_attacker_on_cooldown() -> void:
	_attacker.start_carrying()
	_attacker_comp._slap_cooldown_left = 1.0
	_attacker_comp.request_slap(2)
	assert_false(_target.is_slapped)


func test_invalid_out_of_range() -> void:
	_attacker.start_carrying()
	_target.global_position = Vector3(0, 0, -5.0)
	_attacker_comp.request_slap(2)
	assert_false(_target.is_slapped)


func test_invalid_facing_away() -> void:
	_attacker.start_carrying()
	_target.global_position = Vector3(0, 0, 1.5)
	_attacker_comp.request_slap(2)
	assert_false(_target.is_slapped)


class TestSlapComponent extends SlapComponent:
	var mock_target: Player = null
	func _get_slap_target() -> Player:
		return mock_target


func test_server_initiated_try_fish_slap_succeeds() -> void:
	_attacker.start_carrying()
	_attacker._slap_component.queue_free()
	var test_comp := TestSlapComponent.new()
	test_comp.name = "SlapComponent"
	test_comp.mock_target = _target
	_attacker.add_child(test_comp)
	test_comp.setup(_attacker, null, _players_container)
	_attacker._slap_component = test_comp

	var success := test_comp._try_fish_slap()
	assert_true(success, "_try_fish_slap should return true when target is valid")
	assert_true(_target.is_slapped, "Target should be slapped via _try_fish_slap")
	assert_gt(test_comp._slap_cooldown_left, 0.0, "Attacker cooldown should be set properly without being blocked")
