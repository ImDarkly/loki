extends GutTest

const PLAYER_SCENE := preload("res://entities/player/player.tscn")


func _build_player() -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	autofree(player)
	await get_tree().process_frame
	return player


func test_fishing_component_maps_presentation_states_to_tools_clips() -> void:
	var player := await _build_player()
	var component := player.visual_rig.get_node("PlayerFishingAnimation") as PlayerFishingAnimation
	var animation_player := component.get_node("AnimationPlayer") as AnimationPlayer
	var fishing := player.fishing_mechanic

	assert_true(animation_player.has_animation(&"tools/Fishing_Cast"))
	assert_true(animation_player.has_animation(&"tools/Fishing_Bite"))
	assert_true(animation_player.has_animation(&"tools/Fishing_Catch"))
	assert_true(animation_player.has_animation(&"tools/Fishing_Idle"))
	assert_true(animation_player.has_animation(&"tools/Fishing_Reeling"))
	assert_true(animation_player.has_animation(&"tools/Fishing_Struggling"))
	assert_true(animation_player.has_animation(&"tools/Fishing_Tug"))
	assert_eq(animation_player.get_animation(&"tools/Fishing_Idle").loop_mode, Animation.LOOP_LINEAR)
	assert_eq(animation_player.get_animation(&"tools/Fishing_Reeling").loop_mode, Animation.LOOP_LINEAR)
	assert_eq(animation_player.get_animation(&"tools/Fishing_Struggling").loop_mode, Animation.LOOP_LINEAR)

	fishing.current_state = 1
	assert_eq(component._derive_state(), PlayerFishingAnimation.State.CAST)
	fishing.current_state = 2
	assert_eq(component._derive_state(), PlayerFishingAnimation.State.WAIT)
	fishing.current_state = 3
	fishing._is_fighting = false
	assert_eq(component._derive_state(), PlayerFishingAnimation.State.BITE)
	fishing._is_fighting = true
	fishing.hook_type = 1
	assert_eq(component._derive_state(), PlayerFishingAnimation.State.REEL)
	fishing.hook_type = 2
	assert_eq(component._derive_state(), PlayerFishingAnimation.State.STRUGGLE)
	fishing._pull_spike_timer = 0.3
	assert_eq(component._derive_state(), PlayerFishingAnimation.State.TUG)
	fishing._pull_spike_timer = 0.0
	fishing.current_state = 4
	assert_eq(component._derive_state(), PlayerFishingAnimation.State.CATCH)


func test_fishing_component_resets_for_terminal_player_transitions() -> void:
	var player := await _build_player()
	var component := player.visual_rig.get_node("PlayerFishingAnimation") as PlayerFishingAnimation

	component._set_state(PlayerFishingAnimation.State.CATCH)
	player.reset_for_restart()
	assert_eq(component.get_fishing_state(), PlayerFishingAnimation.State.IDLE)

	component._set_state(PlayerFishingAnimation.State.REEL)
	player._enter_floating()
	assert_eq(component.get_fishing_state(), PlayerFishingAnimation.State.IDLE)

	player.player_state = Player.PlayerState.ALIVE
	component._set_state(PlayerFishingAnimation.State.STRUGGLE)
	player._enter_spectate()
	assert_eq(component.get_fishing_state(), PlayerFishingAnimation.State.IDLE)


func test_fishing_component_rejects_out_of_range_snapshot() -> void:
	var player := await _build_player()
	var component := player.visual_rig.get_node("PlayerFishingAnimation") as PlayerFishingAnimation

	component._set_state(PlayerFishingAnimation.State.WAIT)
	component._apply_synced_state(99)
	assert_eq(component.get_fishing_state(), PlayerFishingAnimation.State.WAIT)


func test_fishing_yields_to_walking_pose_after_cancel_catch_and_reset() -> void:
	var player := await _build_player()
	var reference := await _build_player()
	var rig := player.visual_rig
	var reference_rig := reference.visual_rig
	var fishing := rig.get_node("PlayerFishingAnimation") as PlayerFishingAnimation
	var locomotion_player := rig.get_node("PlayerLocomotionAnimation/AnimationPlayer") as AnimationPlayer
	var fishing_player := rig.get_node("PlayerFishingAnimation/AnimationPlayer") as AnimationPlayer
	var reference_locomotion := reference_rig.get_node("PlayerLocomotionAnimation/AnimationPlayer") as AnimationPlayer
	var reference_fishing := reference_rig.get_node("PlayerFishingAnimation/AnimationPlayer") as AnimationPlayer
	var skeleton := rig.body_mesh.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var reference_skeleton := reference_rig.body_mesh.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D

	player.set_physics_process(false)
	reference.set_physics_process(false)
	fishing.set_physics_process(false)
	(reference_rig.get_node("PlayerFishingAnimation") as PlayerFishingAnimation).set_physics_process(false)
	assert_false(fishing_player.is_playing(), "idle fishing animation must yield to locomotion")
	locomotion_player.stop()
	reference_locomotion.stop()
	fishing_player.stop()
	reference_fishing.stop()
	skeleton.reset_bone_poses()
	reference_skeleton.reset_bone_poses()
	rig.apply_locomotion_state(PlayerLocomotionAnimation.State.WALK)
	reference_rig.apply_locomotion_state(PlayerLocomotionAnimation.State.WALK)
	locomotion_player.advance(0.3)
	reference_locomotion.advance(0.3)
	fishing_player.advance(0.3)
	assert_true(_same_bone_poses(skeleton, reference_skeleton), "walking pose must match isolated walking")

	rig.apply_fishing_state(PlayerFishingAnimation.State.CAST)
	assert_false(locomotion_player.is_playing(), "fishing must have sole control of the skeleton")
	fishing.reset()
	assert_true(locomotion_player.is_playing(), "cancel must resume walking")
	assert_false(fishing_player.is_playing())
	rig.apply_fishing_state(PlayerFishingAnimation.State.CATCH)
	assert_false(locomotion_player.is_playing(), "catch must have sole control of the skeleton")
	fishing.reset()
	assert_true(locomotion_player.is_playing(), "reset must resume walking")
	reference_locomotion.stop()
	reference_rig.apply_locomotion_state(PlayerLocomotionAnimation.State.WALK)
	locomotion_player.advance(0.2)
	reference_locomotion.advance(0.2)
	fishing_player.advance(0.2)
	assert_true(_same_bone_poses(skeleton, reference_skeleton), "walking pose must resume after catch and reset")


func _same_bone_poses(left: Skeleton3D, right: Skeleton3D) -> bool:
	if left.get_bone_count() != right.get_bone_count():
		return false
	for bone in left.get_bone_count():
		if not left.get_bone_pose(bone).is_equal_approx(right.get_bone_pose(bone)):
			return false
	return true
