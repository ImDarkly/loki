extends GutTest


func _seeded_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	return rng


func test_generated_code_in_range() -> void:
	var rng := _seeded_rng()
	for i in range(1000):
		var code: int = NetworkManager.generate_room_code(rng)
		assert_between(code, 100000, 999999, "Code %d should be in 100000–999999" % code)


func test_generated_code_is_six_digits() -> void:
	var rng := _seeded_rng()
	for i in range(1000):
		var code: int = NetworkManager.generate_room_code(rng)
		assert_eq(str(code).length(), 6, "Code %d should have exactly 6 digits" % code)


func test_generated_code_deterministic_with_same_seed() -> void:
	var first: int = NetworkManager.generate_room_code(_seeded_rng())
	var second: int = NetworkManager.generate_room_code(_seeded_rng())
	assert_eq(first, second)


func test_lobby_max_members_is_four() -> void:
	assert_eq(NetworkManager.LOBBY_MAX_MEMBERS, 4)
