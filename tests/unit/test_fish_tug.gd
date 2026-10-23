extends GutTest

const MECHANIC := preload("res://systems/fishing/fishing_mechanic.tscn")
var mechanic: Node3D
var rod: Node3D


func before_each() -> void:
	mechanic = autofree(MECHANIC.instantiate())
	add_child(mechanic)
	mechanic.set_process(false)
	mechanic.set_physics_process(false)
	rod = autofree(Node3D.new())
	add_child(rod)
	rod.global_position = Vector3(0, 1.6, 0)
	mechanic.set_rod_tip(rod)
	mechanic.cast_target_position = Vector3(20, 0, 0)
	mechanic.current_state = mechanic.State.BITE
	mechanic.hook_type = mechanic.HookType.FISH
	mechanic._is_fighting = true
	mechanic._fight_target = 2.0
	mechanic.escape_time_threshold = 10.0
	mechanic.get_node("FishManager").spawn(mechanic.cast_target_position)
	await get_tree().process_frame
	watch_signals(mechanic)


func test_elapsed_time_advances_fight_until_target() -> void:
	mechanic.advance_fight(0.5)
	assert_almost_eq(mechanic._fight_progress, 0.5, 0.001)
	assert_true(mechanic.is_fighting())
	assert_eq(mechanic.current_state, mechanic.State.BITE)
	assert_signal_not_emitted(mechanic, "reel_success")
	mechanic.advance_fight(1.5)
	assert_eq(mechanic.current_state, mechanic.State.SUCCESS)
	assert_signal_emitted_with_parameters(mechanic, "reel_success", [1])


func test_visual_position_interpolates_with_timed_progress() -> void:
	mechanic.advance_fight(0.5)
	mechanic._process(0.0)
	var expected := Vector3(15, -0.5, 0)
	assert_almost_eq(mechanic.get_fish_position().distance_to(expected), 0.0, 0.001)
	var fish: Node3D = mechanic.get_node("FishManager").get_fish()
	assert_almost_eq(fish.global_position.distance_to(expected), 0.0, 0.001)
	assert_eq(mechanic.cast_target_position, Vector3(20, 0, 0))


func test_scroll_resets_escape_without_changing_progress() -> void:
	mechanic.advance_fight(0.75)
	mechanic.notify_scroll()
	assert_eq(mechanic._escape_timer, 0.0)
	assert_almost_eq(mechanic._pull_spike_timer, 0.3, 0.001)
	assert_almost_eq(mechanic._fight_progress, 0.75, 0.001)
	mechanic._process(0.4)
	assert_eq(mechanic._pull_spike_timer, 0.0)
	assert_eq(mechanic._escape_timer, 0.0)
	assert_signal_not_emitted(mechanic, "reel_success")


func test_scroll_postpones_escape_deadline() -> void:
	mechanic.escape_time_threshold = 1.0
	mechanic.advance_fight(0.75)
	mechanic.notify_scroll()
	mechanic.advance_fight(0.5)
	assert_true(mechanic.is_fighting())
	assert_almost_eq(mechanic._escape_timer, 0.5, 0.001)
	assert_signal_not_emitted(mechanic, "escape_launch")
	mechanic.advance_fight(0.5)
	assert_eq(mechanic.current_state, mechanic.State.IDLE)
	assert_signal_emit_count(mechanic, "escape_launch", 1)
	assert_signal_not_emitted(mechanic, "reel_success")


func test_escape_ends_fight_and_cleans_fish_once() -> void:
	mechanic.escape_time_threshold = 1.0
	mechanic.advance_fight(1.0)
	mechanic.advance_fight(2.0)
	assert_false(mechanic.is_fighting())
	assert_eq(mechanic.current_state, mechanic.State.IDLE)
	assert_eq(mechanic.hook_type, mechanic.HookType.NONE)
	assert_eq(mechanic.personal_catch_count, 0)
	assert_null(mechanic.get_node("FishManager").get_fish())
	assert_signal_emit_count(mechanic, "reel_failure", 1)
	assert_signal_emit_count(mechanic, "escape_launch", 1)
	assert_signal_not_emitted(mechanic, "reel_success")


func test_catch_awards_once_and_places_fish_at_rod_depth() -> void:
	mechanic.advance_fight(2.0)
	mechanic.advance_fight(2.0)
	assert_false(mechanic.is_fighting())
	assert_eq(mechanic.current_state, mechanic.State.SUCCESS)
	assert_eq(mechanic.hook_type, mechanic.HookType.NONE)
	assert_eq(mechanic.personal_catch_count, 1)
	assert_signal_emit_count(mechanic, "personal_catch_changed", 1)
	assert_signal_emit_count(mechanic, "reel_success", 1)
	assert_signal_not_emitted(mechanic, "reel_failure")
	assert_eq(mechanic.get_fish_position(), Vector3(0, -0.5, 0))
	var fish: Node3D = mechanic.get_node("FishManager").get_fish()
	assert_eq(fish.global_position, mechanic.get_fish_position())
