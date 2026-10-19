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
	assert_true(_same_bone_poses(skeleton, reference_skeleton), "walking pose must resume after catch and reset")


func _same_bone_poses(left: Skeleton3D, right: Skeleton3D) -> bool:
	if left.get_bone_count() != right.get_bone_count():
		return false
	for bone in left.get_bone_count():
		if not left.get_bone_pose(bone).is_equal_approx(right.get_bone_pose(bone)):
			return false
	return true
