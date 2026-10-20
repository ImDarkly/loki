extends GutTest

const PLAYER_SCENE := preload("res://entities/player/player.tscn")
const TOOLS_ANIMATION_PATH := "res://entities/player/assets/kaykit_animations/Rig_Medium_Tools.glb"


func _build_player() -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	autofree(player)
	await get_tree().process_frame
	return player


func test_a_missing_tools_asset_keeps_locomotion_available() -> void:
	var asset_path := ProjectSettings.globalize_path(TOOLS_ANIMATION_PATH)
	var import_path := "%s.import" % asset_path
	var hidden_asset_path := "%s.test_missing" % asset_path
	var hidden_import_path := "%s.test_missing" % import_path
	var asset_rename := DirAccess.rename_absolute(asset_path, hidden_asset_path)
	if asset_rename != OK:
		assert_eq(asset_rename, OK)
		return
	var has_import := FileAccess.file_exists(import_path)
	if has_import:
		var import_rename := DirAccess.rename_absolute(import_path, hidden_import_path)
		if import_rename != OK:
			DirAccess.rename_absolute(hidden_asset_path, asset_path)
			assert_eq(import_rename, OK)
			return

	var player := await _build_player()
	if has_import:
		assert_eq(DirAccess.rename_absolute(hidden_import_path, import_path), OK)
	assert_eq(DirAccess.rename_absolute(hidden_asset_path, asset_path), OK)
	var rig := player.visual_rig
	var locomotion_player := rig.get_node("PlayerLocomotionAnimation/AnimationPlayer") as AnimationPlayer
	var fishing_player := rig.get_node("PlayerFishingAnimation/AnimationPlayer") as AnimationPlayer
	rig.apply_fishing_state(PlayerFishingAnimation.State.CAST)
	rig.apply_locomotion_state(PlayerLocomotionAnimation.State.WALK)

	assert_push_error("Fishing animation setup error: missing %s. Install and import it as documented in ASSETS.md." % TOOLS_ANIMATION_PATH)
	assert_false(fishing_player.is_playing(), "missing tools asset should skip fishing playback")
	assert_true(locomotion_player.is_playing(), "missing tools asset should retain locomotion playback")


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
	# A single tick crossing the blend duration updates weights on the next evaluation.
	locomotion_player.advance(0.0)
	reference_locomotion.advance(0.0)
	assert_true(_same_bone_poses(skeleton, reference_skeleton), "walking pose must resume after catch and reset")


func _same_bone_poses(left: Skeleton3D, right: Skeleton3D) -> bool:
	if left.get_bone_count() != right.get_bone_count():
		return false
	for bone in left.get_bone_count():
		if not left.get_bone_pose(bone).is_equal_approx(right.get_bone_pose(bone)):
			return false
	return true


func test_cast_transitions_blend_from_idle_and_walking_without_pose_jumps() -> void:
	var player := await _build_player()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var rig := player.visual_rig
	for state in [PlayerLocomotionAnimation.State.IDLE, PlayerLocomotionAnimation.State.WALK]:
		rig.apply_locomotion_state(state)
		_advance_rig(rig, 0.3)
		_assert_smooth_transition(rig, PlayerFishingAnimation.State.CAST, "cast entry")
		rig.apply_fishing_state(PlayerFishingAnimation.State.IDLE)
		_advance_rig(rig, 0.3)
		_assert_smooth_transition(rig, PlayerFishingAnimation.State.CAST, "repeated cast")
		rig.apply_fishing_state(PlayerFishingAnimation.State.IDLE)
		_advance_rig(rig, 0.3)


func test_short_and_finished_casts_blend_to_wait_and_cancel_back_to_walking() -> void:
	var player := await _build_player()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var rig := player.visual_rig
	for cast_duration in [0.05, 0.2, 2.2]:
		rig.apply_fishing_state(PlayerFishingAnimation.State.CAST)
		_advance_rig(rig, cast_duration)
		_assert_smooth_transition(rig, PlayerFishingAnimation.State.WAIT, "cast to wait")
		rig.apply_locomotion_state(PlayerLocomotionAnimation.State.WALK)
		_assert_smooth_transition(rig, PlayerFishingAnimation.State.IDLE, "cancel to walking")
		var locomotion := rig.get_node("PlayerLocomotionAnimation/AnimationPlayer") as AnimationPlayer
		assert_eq(locomotion.current_animation, "movement/Walking_A")
		assert_true(locomotion.is_playing())
		assert_false((rig.get_node("PlayerFishingAnimation/AnimationPlayer") as AnimationPlayer).is_playing())
		_advance_rig(rig, 0.3)


func test_rapid_cancel_and_recast_preserve_the_current_blended_pose() -> void:
	var player := await _build_player()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var rig := player.visual_rig
	rig.apply_locomotion_state(PlayerLocomotionAnimation.State.WALK)
	_advance_rig(rig, 0.3)
	_assert_smooth_transition(rig, PlayerFishingAnimation.State.CAST, "quick cast", 3)
	_assert_smooth_transition(rig, PlayerFishingAnimation.State.WAIT, "quick wait", 3)
	_assert_smooth_transition(rig, PlayerFishingAnimation.State.IDLE, "quick cancel", 3)
	_assert_smooth_transition(rig, PlayerFishingAnimation.State.CAST, "quick recast")
	_assert_smooth_transition(rig, PlayerFishingAnimation.State.IDLE, "recast cancel")


func test_cast_does_not_move_camera_with_fixed_look_input() -> void:
	var player := await _build_player()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var rig := player.visual_rig
	player.rotation.y = 0.4
	player.head.rotation.x = -0.2
	await get_tree().process_frame
	var initial_camera := player.camera.global_transform
	var skeleton := rig._find_skeleton(rig.body_mesh)
	var rest_head := skeleton.global_transform * skeleton.get_bone_global_rest(skeleton.find_bone("head"))
	assert_almost_eq(player.camera.global_position.y, rest_head.origin.y, 0.0001)
	for state in [PlayerFishingAnimation.State.CAST, PlayerFishingAnimation.State.WAIT, PlayerFishingAnimation.State.IDLE]:
		rig.apply_fishing_state(state)
		for frame in 24:
			_advance_rig(rig, 1.0 / 60.0)
			await get_tree().process_frame
			assert_true(player.camera.global_transform.is_equal_approx(initial_camera), "animation must not move or rotate the aiming camera")
	player.head.rotation.x += 0.1
	assert_false(player.camera.global_basis.is_equal_approx(initial_camera.basis), "direct look input must still rotate the camera")


func _advance_rig(rig: PlayerVisualRig, delta: float) -> void:
	for path in ["PlayerLocomotionAnimation/AnimationPlayer", "PlayerFishingAnimation/AnimationPlayer"]:
		var animation := rig.get_node(path) as AnimationPlayer
		if animation.is_playing():
			animation.advance(delta)
	rig._find_skeleton(rig.body_mesh).force_update_all_bone_transforms()


func _assert_smooth_transition(rig: PlayerVisualRig, state: PlayerFishingAnimation.State, label: String, frames: int = 12) -> void:
	var skeleton := rig._find_skeleton(rig.body_mesh)
	var hand := skeleton.find_bone("handslot.r")
	var previous := skeleton.global_transform * skeleton.get_bone_global_pose(hand)
	rig.apply_fishing_state(state)
	for frame in frames:
		_advance_rig(rig, 1.0 / 60.0)
		var current := skeleton.global_transform * skeleton.get_bone_global_pose(hand)
		assert_lt(current.origin.distance_to(previous.origin), 0.08, "%s: hand position must blend" % label)
		var angle := previous.basis.orthonormalized().get_rotation_quaternion().angle_to(current.basis.orthonormalized().get_rotation_quaternion())
		assert_lt(rad_to_deg(angle), 25.0, "%s: hand rotation must blend" % label)
		previous = current
