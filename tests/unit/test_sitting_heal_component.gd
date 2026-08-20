extends GutTest

var _component: SittingHealComponent
var _health: HealthComponent
var _parent: Node


func before_each() -> void:
	_parent = Node.new()
	_parent.name = "Player"
	add_child(_parent)

	_health = HealthComponent.new()
	_health.name = "HealthComponent"
	_parent.add_child(_health)

	_component = SittingHealComponent.new()
	_component.name = "SittingHeal"
	_parent.add_child(_component)
	await get_tree().process_frame


func after_each() -> void:
	if _parent and is_instance_valid(_parent):
		_parent.free()
	_parent = null


func test_starts_not_sitting() -> void:
	assert_false(_component.is_sitting, "is_sitting should start false")


func test_set_sitting_toggles_flag() -> void:
	_component.set_sitting(true)
	assert_true(_component.is_sitting, "is_sitting should be true after set_sitting(true)")
	_component.set_sitting(false)
	assert_false(_component.is_sitting, "is_sitting should be false after set_sitting(false)")


func test_accumulate_heals_after_full_tick() -> void:
	_component.set_sitting(true)
	_component._tick_interval = 18.0
	_health.current_health = 4
	_component._accumulate(18.0)
	assert_eq(_health.current_health, 5, "One full tick should heal 1 HP")


func test_accumulate_heals_multiple_ticks_at_once() -> void:
	_component.set_sitting(true)
	_component._tick_interval = 18.0
	_health.current_health = 3
	_component._accumulate(36.0)
	assert_eq(_health.current_health, 5, "Two full ticks should heal 2 HP")


func test_partial_tick_does_not_heal_but_keeps_progress() -> void:
	_component.set_sitting(true)
	_component._tick_interval = 18.0
	_health.current_health = 4
	_component._accumulate(9.0)
	assert_eq(_health.current_health, 4, "Half a tick should not heal yet")
	assert_almost_eq(_component._heal_progress, 0.5, 0.001, "Fractional progress should be stored")


func test_pause_preserves_progress_and_resume_continues() -> void:
	_component.set_sitting(true)
	_component._tick_interval = 18.0
	_health.current_health = 4
	_component._accumulate(9.0)
	assert_eq(_health.current_health, 4)
	_component.set_sitting(false)
	_component._accumulate(100.0)
	assert_eq(_health.current_health, 4, "Standing up should pause healing")
	_component.set_sitting(true)
	_component._accumulate(9.0)
	assert_eq(_health.current_health, 5, "Re-sitting should resume from preserved progress")


func test_tick_interval_scales_with_max_health() -> void:
	_component._health.max_health = 5
	_component._recompute_tick_interval()
	assert_almost_eq(_component._tick_interval, 18.0, 0.001, "(900/10)/5 should be 18s per HP")
	_component._health.max_health = 10
	_component._recompute_tick_interval()
	assert_almost_eq(_component._tick_interval, 9.0, 0.001, "(900/10)/10 should be 9s per HP")


func test_tick_interval_reads_round_duration() -> void:
	var main := Node3D.new()
	main.name = "main"
	get_node("/root").add_child(main)
	var rm = load("res://systems/round/round_manager.tscn").instantiate()
	rm.name = "RoundManager"
	main.add_child(rm)
	rm.timer.stop()
	rm.round_duration = 600.0
	_component._health.max_health = 5
	_component._recompute_tick_interval()
	assert_almost_eq(_component._tick_interval, 12.0, 0.001, "(600/10)/5 should be 12s per HP")
	main.queue_free()


func test_full_heal_takes_round_duration_tenth() -> void:
	_component.set_sitting(true)
	_component._health.max_health = 10
	_component._health.current_health = 0
	_component._tick_interval = (900.0 / 10.0) / 10.0
	var total_time := 0.0
	while _health.current_health < _health.max_health:
		_component._accumulate(_component._tick_interval)
		total_time += _component._tick_interval
	assert_almost_eq(total_time, 90.0, 0.001, "Full heal should take round_duration / 10")


func test_no_heal_at_full_health() -> void:
	_component.set_sitting(true)
	_component._tick_interval = 18.0
	_health.current_health = _health.max_health
	_component._accumulate(1000.0)
	assert_eq(_health.current_health, _health.max_health, "Health should not exceed max")
	assert_eq(_component._heal_progress, 0.0, "Progress should reset at full health")


func test_two_sitters_accumulate_independently() -> void:
	var parent2 := Node.new()
	parent2.name = "Player2"
	add_child(parent2)
	var health2 := HealthComponent.new()
	health2.name = "HealthComponent"
	parent2.add_child(health2)
	health2.current_health = 3
	var comp2 := SittingHealComponent.new()
	comp2.name = "SittingHeal"
	parent2.add_child(comp2)
	await get_tree().process_frame

	_component.set_sitting(true)
	comp2.set_sitting(true)
	_component._tick_interval = 18.0
	comp2._tick_interval = 18.0
	_health.current_health = 4
	_component._accumulate(18.0)
	comp2._accumulate(18.0)
	assert_eq(_health.current_health, 5, "First sitter should heal")
	assert_eq(health2.current_health, 4, "Second sitter should heal independently")
	parent2.free()


func test_process_skips_when_not_sitting() -> void:
	_health.current_health = 4
	_component._tick_interval = 18.0
	_component._process(18.0)
	assert_eq(_health.current_health, 4, "No accumulation while standing")


func test_reset_stands_up_and_clears_progress() -> void:
	_component.set_sitting(true)
	_component._tick_interval = 18.0
	_health.current_health = 4
	_component._accumulate(9.0)
	_component.reset()
	assert_false(_component.is_sitting, "reset should stand the player up")
	assert_eq(_component._heal_progress, 0.0, "reset should clear heal progress")