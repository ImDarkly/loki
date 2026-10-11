extends GutTest

var fish_manager: Node3D


func before_each() -> void:
	var scene = load("res://systems/fishing/fish_manager.tscn")
	fish_manager = autofree(scene.instantiate())
	add_child(fish_manager)
	await get_tree().process_frame


func test_set_fight_mode_enables_impulse_and_speed() -> void:
	fish_manager.spawn(Vector3.ZERO)
	var fish = fish_manager.get_fish()
	assert_not_null(fish, "Fish should be spawned")
	
	fish_manager.set_fight_mode(true)
	
	var anim_player: AnimationPlayer = null
	for child in fish.find_children("*", "AnimationPlayer", true, false):
		anim_player = child as AnimationPlayer
		if anim_player:
			break
	assert_not_null(anim_player, "Fish should have AnimationPlayer")
	assert_eq(anim_player.current_animation, fish_manager.FIGHT_ANIMATION, "Fight mode should play FIGHT_ANIMATION")
	assert_eq(anim_player.speed_scale, fish_manager.FIGHT_SPEED_SCALE, "Fight mode should scale speed to FIGHT_SPEED_SCALE")

	fish_manager.set_fight_mode(false)
	assert_eq(anim_player.current_animation, fish_manager.SWIM_ANIMATION, "Exiting fight mode should play SWIM_ANIMATION")
	assert_eq(anim_player.speed_scale, 1.0, "Exiting fight mode should reset speed to 1.0")


func test_set_fight_mode_fallback_when_impulse_absent() -> void:
	var custom_fish = Node3D.new()
	var anim_player = AnimationPlayer.new()
	var lib = AnimationLibrary.new()
	var anim = Animation.new()
	lib.add_animation("Fish_Armature|Swimming_Normal", anim)
	anim_player.add_animation_library("", lib)
	custom_fish.add_child(anim_player)
	autofree(custom_fish)
	
	fish_manager._fish_node = custom_fish
	fish_manager.set_fight_mode(true)
	
	assert_eq(anim_player.current_animation, fish_manager.SWIM_ANIMATION, "Should fallback to SWIM_ANIMATION when Impulse absent")
	assert_eq(anim_player.speed_scale, fish_manager.FIGHT_SPEED_SCALE, "Should still scale speed in fallback")


func test_play_catch_clip_prefers_out_of_water() -> void:
	fish_manager.spawn(Vector3.ZERO)
	var fish = fish_manager.get_fish()
	
	var played = fish_manager.play_catch_clip()
	assert_true(played, "play_catch_clip should return true when catch animation played")
	
	var anim_player: AnimationPlayer = null
	for child in fish.find_children("*", "AnimationPlayer", true, false):
		anim_player = child as AnimationPlayer
		if anim_player:
			break
	assert_not_null(anim_player)
	assert_eq(anim_player.current_animation, fish_manager.CATCH_ANIMATION, "Should play CATCH_ANIMATION clip")


func test_play_catch_clip_fallback_when_out_of_water_absent() -> void:
	var custom_fish = Node3D.new()
	var anim_player = AnimationPlayer.new()
	var lib = AnimationLibrary.new()
	var anim = Animation.new()
	lib.add_animation("Fish_Armature|Swimming_Normal", anim)
	anim_player.add_animation_library("", lib)
	custom_fish.add_child(anim_player)
	autofree(custom_fish)
	
	fish_manager._fish_node = custom_fish
	var played = fish_manager.play_catch_clip()
	
	assert_true(played, "play_catch_clip should return true with fallback")
	assert_eq(anim_player.current_animation, fish_manager.SWIM_ANIMATION, "Should fallback to SWIM_ANIMATION when Out_Of_Water/Death absent")


func test_cleanup_fish_if_current() -> void:
	fish_manager.spawn(Vector3.ZERO)
	var fish = fish_manager.get_fish()
	assert_not_null(fish)
	
	fish_manager.cleanup_fish_if_current(fish)
	assert_null(fish_manager.get_fish(), "Fish should be cleaned up if it matches current fish")
	
	fish_manager.spawn(Vector3.ZERO)
	var fish2 = fish_manager.get_fish()
	var other_fish = Node3D.new()
	autofree(other_fish)
	fish_manager.cleanup_fish_if_current(other_fish)
	assert_eq(fish_manager.get_fish(), fish2, "Should not cleanup if fish does not match current fish")
