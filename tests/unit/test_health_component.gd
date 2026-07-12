extends GutTest

var health: HealthComponent


func before_each() -> void:
	health = HealthComponent.new()
	add_child(health)
	await get_tree().process_frame


func test_initial_health_equals_max() -> void:
	assert_eq(health.current_health, health.max_health, "Should start at max_health")


func test_take_damage_reduces_health() -> void:
	health.current_health = 5
	health.take_damage(2)
	assert_eq(health.current_health, 3, "Should reduce health by damage amount")


func test_take_damage_clamps_at_zero() -> void:
	health.current_health = 1
	health.take_damage(5)
	assert_eq(health.current_health, 0, "Should clamp at 0")


func test_take_damage_emits_health_changed() -> void:
	health.current_health = 5
	watch_signals(health)
	health.take_damage(2)
	assert_signal_emitted(health, "health_changed")
	assert_signal_emit_count(health, "health_changed", 1, "Should emit exactly once")


func test_health_changed_old_and_new_values() -> void:
	health.current_health = 5
	var old_val := health.current_health
	health.take_damage(2)
	assert_eq(old_val - health.current_health, 2, "Difference should equal damage")


func test_died_emitted_at_zero() -> void:
	health.current_health = 2
	watch_signals(health)
	health.take_damage(2)
	assert_signal_emitted(health, "died")


func test_died_not_emitted_when_still_alive() -> void:
	health.current_health = 5
	watch_signals(health)
	health.take_damage(2)
	assert_signal_not_emitted(health, "died")


func test_died_not_emitted_twice_on_repeated_zero_hp_damage() -> void:
	health.current_health = 2
	watch_signals(health)
	health.take_damage(2)
	health.take_damage(5)
	assert_signal_emit_count(health, "died", 1, "Should emit exactly once, even on repeated damage at 0")


func test_reset_to_max_restores_health() -> void:
	health.current_health = 0
	health.reset_to_max()
	assert_eq(health.current_health, health.max_health, "Should restore to max_health")


func test_reset_to_max_emits_health_changed() -> void:
	health.current_health = 0
	watch_signals(health)
	health.reset_to_max()
	assert_signal_emitted(health, "health_changed")


func test_reset_to_max_allows_died_to_be_emitted_again() -> void:
	health.current_health = 2
	health.take_damage(2)
	assert_eq(health.current_health, 0)
	watch_signals(health)
	health.reset_to_max()
	health.take_damage(health.max_health)
	assert_signal_emitted(health, "died", "died should emit again after reset_to_max and new lethal damage")


func test_is_alive_returns_true_when_positive() -> void:
	health.current_health = 1
	assert_true(health.is_alive(), "Should be alive when health > 0")


func test_is_alive_returns_false_at_zero() -> void:
	health.current_health = 0
	assert_false(health.is_alive(), "Should not be alive when health == 0")
