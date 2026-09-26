extends Node3D

enum State { IDLE, CASTING, WAITING, BITE, SUCCESS }

signal bite_occurred(fish_position: Vector3)
signal reel_success(quota: int)
signal reel_failure()
signal escape_launch(direction: Vector3, strength: float)
signal escape_telegraph_changed(intensity: float)
signal personal_catch_changed(count: int)

@export var max_tether_range: float = 25.0

enum HookType { NONE, FISH, PLAYER }
var hook_type: HookType = HookType.NONE
var _tether_target: Player = null

@export var min_bite_delay: float = 3.0
@export var max_bite_delay: float = 8.0

@export var gravity_strength: float = 9.8

var _current_flight_duration: float

@onready var bite_timer: Timer = $BiteTimer
@onready var bite_audio: AudioStreamPlayer = $BiteAudio
@onready var casting_timer: Timer = $CastingTimer
@onready var personal_label: Label = $CanvasLayer/PersonalLabel
@onready var catch_feedback_manager: Node3D = $CatchFeedbackManager

var current_state: State = State.IDLE
var visual_line_node: MeshInstance3D = null
var line_material: ORMMaterial3D = null
var bobber_node: MeshInstance3D = null
var cast_target_position: Vector3
var _flight_start_position: Vector3
var _flight_start_time: int
var _launch_velocity: Vector3

var personal_catch_count: int = 0

var _zone_manager_ref: Node3D = null
var _round_manager_ref: Node = null
var _active_zone_index: int = -1

var is_local_render: bool = true:
	set(value):
		is_local_render = value
		if is_node_ready():
			$CanvasLayer.visible = value
var _prev_remote_state: int = -1

var _line_twitch: float = 0.0
var _bite_time: float = 0.0
var _is_fighting: bool = false
var _fight_initial_distance: float = 0.0
@export var fighting_pull_strength: float = 0.5
@export var fighting_spike_pull: float = 1.5
@export var escape_time_threshold: float = 1.8
@export var escape_launch_strength: float = 10.0
var _fight_progress: float = 0.0
var _fight_target: float = 0.0
var _rod_tip_ref: Node3D = null
var _cached_fishing_active: bool = true
var _escape_timer: float = 0.0
var _pull_spike_timer: float = 0.0
var _telegraph_intensity: float = 0.0
var _escape_telegraph_audio: AudioStreamPlayer = null

const LINE_SEGMENTS: int = 4
const SHORE_CONTACT_TOLERANCE: float = 0.75


func is_fighting() -> bool:
	return _is_fighting


func can_cast() -> bool:
	return current_state == State.IDLE and _is_fishing_active()


func _is_fishing_active() -> bool:
	if _round_manager_ref and is_instance_valid(_round_manager_ref):
		_cached_fishing_active = _round_manager_ref.fishing_active
	return _cached_fishing_active


func on_fish_fled(target_client_id: int = -1) -> void:
	if target_client_id != -1 and target_client_id != _get_owner_client_id():
		return
	if not is_local_render:
		return
	if current_state not in [State.BITE]:
		return
	_is_fighting = false
	_escape_timer = 0.0
	_telegraph_intensity = 0.0
	_stop_telegraph()
	_report_zone_leave()
	_snap_bobber_to_rod()
	$FishManager.cleanup()
	current_state = State.IDLE
	hook_type = HookType.NONE
	_tether_target = null
	reel_failure.emit()


func advance_fight(delta: float) -> void:
	if not _is_fighting:
		return
	if hook_type == HookType.PLAYER:
		return
	var caster := get_parent() as Player
	if caster and is_instance_valid(caster):
		if caster.global_position.distance_to(cast_target_position) > max_tether_range:
			_on_hook_rejected()
			return
	_fight_progress += delta

	if hook_type != HookType.PLAYER:
		_escape_timer += delta
		_update_telegraph()
		if _escape_timer >= escape_time_threshold:
			_trigger_escape_launch()
			return

	if _fight_progress >= _fight_target:
		_complete_fight_catch()


@rpc("any_peer", "reliable", "call_remote")
func notify_scroll() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if multiplayer.has_multiplayer_peer():
		var sender_id := multiplayer.get_remote_sender_id()
		if sender_id != 0 and sender_id != 1 and sender_id != _get_owner_client_id():
			return
	_escape_timer = 0.0
	_pull_spike_timer = 0.3


func _process_pull(delta: float) -> void:
	var p := get_parent() as Player
	if not p or not is_instance_valid(p) or not is_instance_valid(_tether_target):
		return
	var to_caster := p.global_position - _tether_target.global_position
	to_caster.y = 0.0
	var dist := to_caster.length()
	if dist < 1.5:
		return
	var dir := to_caster.normalized() if dist > 0.001 else Vector3.ZERO
	var initial_dist: float = max(_fight_initial_distance, 0.01)
	var pull_mult: float = clamp(dist / initial_dist, 0.1, 1.0)
	var is_spiked := _pull_spike_timer > 0
	var current_pull := fighting_spike_pull if is_spiked else 0.0
	var pull_displacement: Vector3 = dir * current_pull * pull_mult * 10.0 * delta
	var victim_id := _tether_target._parse_owner_id()
	if multiplayer.has_multiplayer_peer():
		if victim_id == 1:
			_tether_target._do_apply_hook_pull(pull_displacement)
		else:
			_tether_target._apply_hook_pull.rpc_id(victim_id, pull_displacement)
	else:
		_tether_target._do_apply_hook_pull(pull_displacement)


@rpc("any_peer", "reliable", "call_remote")
func request_hook_player(target_id: int) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var reject_id := multiplayer.get_remote_sender_id() if multiplayer.has_multiplayer_peer() else 1
	if reject_id == 0:
		reject_id = multiplayer.get_unique_id()
	var p := get_parent() as Player
	if not p or not is_instance_valid(p):
		return
	var attacker: Player = null
	if multiplayer.has_multiplayer_peer():
		var sender_id := multiplayer.get_remote_sender_id()
		if sender_id == 0:
			sender_id = multiplayer.get_unique_id()
		attacker = p._find_player_by_id(sender_id)
	else:
		attacker = p
	if not attacker or not is_instance_valid(attacker):
		if multiplayer.has_multiplayer_peer():
			p.rpc_id(reject_id, "_reject_hook_request")
		else:
			p._reject_hook_request()
		return
	if attacker != p:
		if multiplayer.has_multiplayer_peer():
			p.rpc_id(reject_id, "_reject_hook_request")
		else:
			p._reject_hook_request()
		return
	if attacker.player_state != Player.PlayerState.ALIVE:
		if multiplayer.has_multiplayer_peer():
			p.rpc_id(reject_id, "_reject_hook_request")
		else:
			p._reject_hook_request()
		return
	if not _is_fishing_active():
		if multiplayer.has_multiplayer_peer():
			p.rpc_id(reject_id, "_reject_hook_request")
		else:
			p._reject_hook_request()
		return
	if current_state != State.IDLE or hook_type != HookType.NONE or _is_fighting:
		if multiplayer.has_multiplayer_peer():
			p.rpc_id(reject_id, "_reject_hook_request")
		else:
			p._reject_hook_request()
		return
	var target := attacker._find_player_by_id(target_id)
	if not target or not is_instance_valid(target) or target.player_state != Player.PlayerState.FLOATING or target == attacker or (target.fishing_mechanic and target.fishing_mechanic.hook_type == HookType.PLAYER):
		if multiplayer.has_multiplayer_peer():
			p.rpc_id(reject_id, "_reject_hook_request")
		else:
			p._reject_hook_request()
		return
	var dist := attacker.global_position.distance_to(target.global_position)
	if dist > attacker.max_cast_range:
		if multiplayer.has_multiplayer_peer():
			p.rpc_id(reject_id, "_reject_hook_request")
		else:
			p._reject_hook_request()
		return

	_apply_predicted_player_hook(target)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		var client_id := multiplayer.get_remote_sender_id()
		if client_id != 0 and client_id != 1 and p and is_instance_valid(p):
			p.rpc_id(client_id, "_sync_cast_target", cast_target_position)
			p.rpc_id(client_id, "_sync_fishing_state", current_state)


func _apply_predicted_player_hook(target: Player) -> void:
	_report_zone_leave()
	_active_zone_index = -1
	_cleanup_all()
	hook_type = HookType.PLAYER
	_tether_target = target
	cast_target_position = target.global_position
	current_state = State.BITE
	_bite_time = 0.0
	_is_fighting = true
	_start_telegraph()
	var player := get_parent() as Node3D
	if player and is_instance_valid(player):
		_fight_initial_distance = player.global_position.distance_to(cast_target_position)
	_fight_target = randf_range(2.0, 8.0)
	_fight_progress = 0.0
	if bite_timer:
		bite_timer.stop()
	if casting_timer:
		casting_timer.stop()
	_create_bobber(target.global_position)
	_create_line_node()
	_rebuild_line()
	_play_bite_feedback()


func _on_hook_rejected() -> void:
	if bite_timer:
		bite_timer.stop()
	if casting_timer:
		casting_timer.stop()
	_is_fighting = false
	_escape_timer = 0.0
	_telegraph_intensity = 0.0
	_pull_spike_timer = 0.0
	_stop_telegraph()
	_report_zone_leave()
	_snap_bobber_to_rod()
	$FishManager.cleanup()
	current_state = State.IDLE
	hook_type = HookType.NONE
	_tether_target = null
	reel_failure.emit()


func _update_telegraph() -> void:
	var new_intensity: float = clamp(_escape_timer / escape_time_threshold, 0.0, 1.0)
	if not is_equal_approx(new_intensity, _telegraph_intensity):
		_telegraph_intensity = new_intensity
		escape_telegraph_changed.emit(_telegraph_intensity)
		if _escape_telegraph_audio:
			_escape_telegraph_audio.pitch_scale = 0.5 + _telegraph_intensity * 1.5


func _trigger_escape_launch() -> void:
	var player: Node3D = get_parent() as Node3D
	var direction: Vector3 = Vector3.FORWARD
	if player:
		var to_fish: Vector3 = cast_target_position - player.global_position
		if to_fish.length() > 0.001:
			direction = to_fish.normalized()
	direction.y = 0.3
	direction = direction.normalized()

	_is_fighting = false
	_escape_timer = 0.0
	_telegraph_intensity = 0.0
	_stop_telegraph()
	_report_zone_leave()
	_snap_bobber_to_rod()
	$FishManager.cleanup()
	current_state = State.IDLE
	hook_type = HookType.NONE
	_tether_target = null
	reel_failure.emit()
	escape_launch.emit(direction, escape_launch_strength)


func _start_telegraph() -> void:
	_escape_timer = 0.0
	_telegraph_intensity = 0.0
	_escape_telegraph_audio.play()


func _stop_telegraph() -> void:
	_telegraph_intensity = 0.0
	if _escape_telegraph_audio:
		_escape_telegraph_audio.stop()
	escape_telegraph_changed.emit(0.0)


func _complete_fight_catch() -> void:
	if hook_type == HookType.PLAYER:
		# TODO(274): inverted pull
		_is_fighting = false
		_escape_timer = 0.0
		_telegraph_intensity = 0.0
		_stop_telegraph()
		_report_zone_leave()
		_snap_bobber_to_rod()
		$FishManager.cleanup()
		current_state = State.IDLE
		hook_type = HookType.NONE
		_tether_target = null
		return

	_is_fighting = false
	_escape_timer = 0.0
	_telegraph_intensity = 0.0
	_stop_telegraph()
	current_state = State.SUCCESS
	hook_type = HookType.NONE
	_tether_target = null
	personal_catch_count += 1
	personal_catch_changed.emit(personal_catch_count)
	reel_success.emit(personal_catch_count)
	_report_zone_leave()
	$FishManager.cleanup()
	catch_feedback_manager.play_catch_success()


func _on_personal_catch_changed(count: int) -> void:
	personal_label.text = "Your catches: %d" % count


func _try_find_zone_manager() -> void:
	if _zone_manager_ref:
		return
	var zm := get_tree().root.find_child("ZoneManager", true, false)
	if zm:
		_zone_manager_ref = zm


func _try_find_round_manager() -> void:
	if _round_manager_ref:
		return
	var rm := get_node_or_null("/root/main/RoundManager")
	if rm:
		_round_manager_ref = rm


func _ready() -> void:
	var dbg = get_node_or_null("/root/DebugOverlay")
	if dbg:
		var sys_name := name
		var caster := get_parent() as Player
		if caster and is_instance_valid(caster):
			sys_name = "FishingMechanic_" + caster.name
		dbg.register_system(sys_name, self)
	_try_find_zone_manager()
	_try_find_round_manager()
	bite_timer.one_shot = true
	bite_timer.timeout.connect(_on_bite_timer_timeout)
	bite_audio.stream = _generate_rumble_stream()

	casting_timer.one_shot = true
	casting_timer.timeout.connect(_on_casting_timer_timeout)

	personal_label.text = "Your catches: 0"
	personal_catch_changed.connect(_on_personal_catch_changed)
	catch_feedback_manager.feedback_completed.connect(_on_catch_feedback_completed)

	if not InputMap.has_action("reel"):
		InputMap.add_action("reel")
		var reel_mouse := InputEventMouseButton.new()
		reel_mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("reel", reel_mouse)

	if not InputMap.has_action("reel_fight"):
		InputMap.add_action("reel_fight")
		var reel_scroll := InputEventMouseButton.new()
		reel_scroll.button_index = MOUSE_BUTTON_WHEEL_DOWN
		InputMap.action_add_event("reel_fight", reel_scroll)

	if not InputMap.has_action("cast_line"):
		InputMap.add_action("cast_line")
		var cast_mouse := InputEventMouseButton.new()
		cast_mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("cast_line", cast_mouse)

	line_material = ORMMaterial3D.new()
	line_material.albedo_color = Color(1.0, 1.0, 1.0)
	line_material.shading_mode = ORMMaterial3D.SHADING_MODE_UNSHADED
	line_material.cull_mode = ORMMaterial3D.CULL_DISABLED

	var eta: AudioStreamPlayer = AudioStreamPlayer.new()
	eta.name = "EscapeTelegraphAudio"
	eta.bus = "SFX"
	add_child(eta)
	_escape_telegraph_audio = eta
	_escape_telegraph_audio.stream = _generate_telegraph_stream()


func set_rod_tip(tip: Node3D) -> void:
	_rod_tip_ref = tip


func get_rod_tip_position() -> Vector3:
	return _get_rod_tip_position()


func _get_rod_tip_position() -> Vector3:
	if _rod_tip_ref and is_instance_valid(_rod_tip_ref):
		return _rod_tip_ref.global_position
	return global_position + Vector3(0, 1.6, -0.5)


static func _compute_launch_velocity(
	start: Vector3, target: Vector3, duration: float, gravity: float
) -> Vector3:
	var g := Vector3(0, -gravity, 0)
	return (target - start - 0.5 * g * duration * duration) / duration


func _get_bobber_position() -> Vector3:
	if current_state == State.CASTING:
		var elapsed := (Time.get_ticks_msec() - _flight_start_time) / 1000.0
		elapsed = min(elapsed, _current_flight_duration)
		return _flight_start_position \
			+ _launch_velocity * elapsed \
			+ 0.5 * Vector3(0, -gravity_strength, 0) * elapsed * elapsed
	if current_state in [State.WAITING, State.BITE]:
		if hook_type == HookType.PLAYER and is_instance_valid(_tether_target):
			return _tether_target.global_position
		return cast_target_position
	if is_instance_valid(bobber_node):
		return bobber_node.position
	return cast_target_position


func _find_floating_player_near(pos: Vector3) -> Player:
	var root := get_tree().root.get_node_or_null("/root/main/Players")
	if not root:
		root = get_tree().root.find_child("Players", true, false)
	if not root:
		return null
	for child in root.get_children():
		if child is Player:
			var player := child as Player
			if is_instance_valid(player) and player.player_state == Player.PlayerState.FLOATING:
				if player.global_position.distance_to(pos) < 1.5:
					return player
	return null


func _handle_remote_transition(to_state: int) -> void:
	match to_state:
		State.CASTING:
			_cleanup_all()
			_launch_velocity = _compute_launch_velocity(
				_flight_start_position, cast_target_position, _current_flight_duration, gravity_strength
			)
			_flight_start_time = Time.get_ticks_msec()
			_create_bobber(cast_target_position)
			_create_line_node()
			_rebuild_line()

		State.BITE:
			var floating_player = _find_floating_player_near(cast_target_position)
			if floating_player:
				hook_type = HookType.PLAYER
				_tether_target = floating_player
				_is_fighting = true
			if is_instance_valid(bobber_node):
				bobber_node.visible = true
			else:
				_create_bobber(cast_target_position)
				_create_line_node()
				_rebuild_line()
			_line_twitch = 0.0
			var tw := create_tween()
			tw.tween_property(self, "_line_twitch", 0.3, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(self, "_line_twitch", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			if hook_type != HookType.PLAYER:
				$FishManager.spawn(cast_target_position)

		State.IDLE, State.SUCCESS:
			_is_fighting = false
			_snap_bobber_to_rod()
			$FishManager.cleanup()
			hook_type = HookType.NONE
			_tether_target = null


func _check_rescue_complete() -> bool:
	# SHORE_CONTACT rescue: the hook pull teleport is not blocked, the following
	# floating-physics tick ejects the victim out of the island wall, so a towed
	# victim equilibrates just outside ISLAND_RADIUS and never crosses it.
	# SHORE_CONTACT_TOLERANCE covers capsule radius 0.3 + pull step + sync jitter.
	# complete_water_rescue snaps the victim radially onto the deck
	# (ISLAND_RADIUS - inset, deck rest height, velocity zeroed); without the snap
	# the victim would stay at water level and instantly re-enter FLOATING.
	if not MapConfig.is_within_radius(_tether_target.global_position, MapConfig.MAP_CENTER, MapConfig.ISLAND_RADIUS + SHORE_CONTACT_TOLERANCE):
		return false
	_tether_target.complete_water_rescue()
	_on_hook_rejected()
	_notify_hook_end()
	return true


func _check_tether_pop() -> bool:
	var caster := get_parent() as Player
	if not caster or not is_instance_valid(caster):
		return false
	if caster.global_position.distance_to(_tether_target.global_position) <= max_tether_range:
		return false
	_on_hook_rejected()
	_notify_hook_end()
	return true


func _notify_hook_end() -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	var caster := get_parent() as Player
	if not caster or not is_instance_valid(caster):
		return
	var caster_id := caster._parse_owner_id()
	if caster_id == multiplayer.get_unique_id():
		return
	caster.rpc_id(caster_id, "_reject_hook_request")


func _physics_process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		if hook_type == HookType.PLAYER and _is_fighting and is_instance_valid(_tether_target):
			if _check_rescue_complete():
				return
			if _check_tether_pop():
				return
			_process_pull(delta)


func _process(delta: float) -> void:
	if not is_local_render and current_state != _prev_remote_state:
		_handle_remote_transition(current_state)
		_prev_remote_state = current_state

	_pull_spike_timer = max(0.0, _pull_spike_timer - delta)

	match current_state:
		State.CASTING, State.WAITING, State.BITE:
			if hook_type == HookType.PLAYER and is_instance_valid(_tether_target):
				cast_target_position = _tether_target.global_position
			_update_bobber()
			_rebuild_line()

			if current_state == State.BITE:
				_bite_time += delta
				if is_local_render and not _is_fighting:
					if _bite_time >= 1.0:
						_report_zone_leave()
						_snap_bobber_to_rod()
						hook_type = HookType.NONE
						_tether_target = null
						current_state = State.IDLE
						$FishManager.cleanup()
						reel_failure.emit()
						return

					if Input.is_action_just_pressed("reel"):
						_is_fighting = true
						_start_telegraph()
						var player := get_parent() as Node3D
						if player:
							_fight_initial_distance = player.global_position.distance_to(cast_target_position)
						_fight_target = randf_range(2.0, 8.0)
						_fight_progress = 0.0

			if is_local_render and current_state == State.WAITING and Input.is_action_just_pressed("reel"):
				bite_timer.stop()
				_report_zone_leave()
				_snap_bobber_to_rod()
				hook_type = HookType.NONE
				_tether_target = null
				current_state = State.IDLE

		State.IDLE:
			if is_instance_valid(bobber_node):
				bobber_node.position = _get_rod_tip_position() + Vector3(0, -0.1, 0)
				_rebuild_line()


func _detect_floating_player() -> Player:
	# TODO(274): player-ID deferral.
	var p := get_parent() as Player
	if not p or not is_instance_valid(p):
		return null
	if not p.is_inside_tree():
		return null
	var space_state := p.get_world_3d().direct_space_state if p.has_method("get_world_3d") and p.get_world_3d() else null
	if space_state == null:
		return null
	var cam := p.camera if (p and is_instance_valid(p) and "camera" in p and is_instance_valid(p.camera)) else null
	if not cam or not is_instance_valid(cam):
		return null
	var origin := cam.global_position
	var dir := -cam.global_transform.basis.z
	var params := PhysicsRayQueryParameters3D.new()
	params.from = origin
	params.to = origin + dir * p.max_cast_range
	params.collision_mask = Player.PLAYERS_LAYER
	params.exclude = [p.get_rid()] if p.has_method("get_rid") else []
	var result := space_state.intersect_ray(params)
	var hit := result and result.has("collider")
	if not hit:
		return null
	var collider := result.collider as Node3D
	var current: Node = collider
	while current != null and is_instance_valid(current):
		if current is Player:
			var player := current as Player
			if player != p and is_instance_valid(player) and player.player_state == Player.PlayerState.FLOATING:
				return player
		current = current.get_parent()
	return null


func try_cast_with_detection(target: Vector3, flight_time: float) -> void:
	if current_state in [State.BITE, State.SUCCESS]:
		return
	var floating_player := _detect_floating_player()
	if floating_player and is_instance_valid(floating_player):
		var target_id := floating_player._parse_owner_id()
		if multiplayer.has_multiplayer_peer():
			if multiplayer.is_server():
				request_hook_player(target_id)
			else:
				request_hook_player.rpc_id(1, target_id)
				_apply_predicted_player_hook(floating_player)
		else:
			request_hook_player(target_id)
	else:
		hook_type = HookType.FISH
		_tether_target = null
		cast(target, flight_time)


func cast(target_position: Vector3, flight_time: float) -> void:
	if current_state in [State.BITE, State.SUCCESS]:
		return

	_report_zone_leave()
	_active_zone_index = -1
	_cleanup_all()

	current_state = State.CASTING
	hook_type = HookType.FISH
	_tether_target = null

	cast_target_position = target_position
	cast_target_position.y = 0.0

	_current_flight_duration = flight_time
	_flight_start_position = _get_rod_tip_position()
	_flight_start_time = Time.get_ticks_msec()
	_launch_velocity = _compute_launch_velocity(
		_flight_start_position, cast_target_position, _current_flight_duration, gravity_strength
	)

	_create_bobber(_get_bobber_position())
	_create_line_node()
	_rebuild_line()

	casting_timer.start(_current_flight_duration)
	print("Cast: projectile arc, entering CASTING state")


func _on_casting_timer_timeout() -> void:
	if current_state != State.CASTING:
		return
	current_state = State.WAITING
	var zone_index := _get_zone_index_for_cast_target()
	if zone_index != _get_no_zone_index():
		_active_zone_index = zone_index
		_report_zone_enter(zone_index)
	var delay: float = randf_range(min_bite_delay, max_bite_delay)
	bite_timer.start(delay)
	print("Cast: waiting %.2f seconds for bite" % delay)


func _on_bite_timer_timeout() -> void:
	if _active_zone_index == -1:
		_report_zone_leave()
		current_state = State.IDLE
		_snap_bobber_to_rod()
		$FishManager.cleanup()
		catch_feedback_manager.play_dead_zone_feedback()
		return

	current_state = State.BITE
	_bite_time = 0.0
	_is_fighting = false
	if is_instance_valid(bobber_node):
		bobber_node.visible = true
	_play_bite_feedback()
	$FishManager.spawn(cast_target_position)
	bite_occurred.emit(cast_target_position)
	print("Bite! Press left mouse to catch")


func _get_zone_index_for_cast_target() -> int:
	_try_find_zone_manager()
	if not is_instance_valid(_zone_manager_ref):
		return _get_no_zone_index()
	return _zone_manager_ref.get_zone_index_for_point(cast_target_position)


func _get_no_zone_index() -> int:
	_try_find_zone_manager()
	if is_instance_valid(_zone_manager_ref) and _zone_manager_ref.has_method("get_no_zone_index"):
		return _zone_manager_ref.get_no_zone_index()
	return -1


func _create_line_node() -> void:
	visual_line_node = MeshInstance3D.new()
	get_tree().root.add_child(visual_line_node)
	visual_line_node.material_override = line_material


func _rebuild_line() -> void:
	if not is_instance_valid(visual_line_node):
		return

	var start := _get_rod_tip_position()
	var end := _get_bobber_position()

	line_material.albedo_color.a = 1.0

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	var line_width: float = 0.025
	var dir := (end - start).normalized()
	var right := dir.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	var half_w := right * line_width * 0.5

	for i in range(LINE_SEGMENTS + 1):
		var t := float(i) / float(LINE_SEGMENTS)
		var pos := start.lerp(end, t)
		if t > 0.0 and t < 1.0:
			pos.y += sin(t * PI * LINE_SEGMENTS) * _line_twitch

		st.add_vertex(pos - half_w)
		st.add_vertex(pos + half_w)

	visual_line_node.mesh = st.commit()


func _create_bobber(position: Vector3) -> void:
	bobber_node = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.04
	sphere.height = 0.08
	bobber_node.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.2)
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	bobber_node.material_override = mat

	bobber_node.position = position
	get_tree().root.add_child(bobber_node)


func _update_bobber() -> void:
	if not is_instance_valid(bobber_node):
		return

	bobber_node.position = _get_bobber_position()
	if current_state == State.BITE:
		bobber_node.position.y += sin(_bite_time * 3.0) * 0.008


func _play_bite_feedback() -> void:
	bite_audio.stop()
	bite_audio.play()

	_line_twitch = 0.0
	var tw := create_tween()
	tw.tween_property(self, "_line_twitch", 0.3, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_line_twitch", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _cleanup_bobber() -> void:
	if is_instance_valid(bobber_node):
		bobber_node.queue_free()
		bobber_node = null


func _cleanup_line() -> void:
	if is_instance_valid(visual_line_node):
		visual_line_node.queue_free()
		visual_line_node = null
	_line_twitch = 0.0


func _cleanup_all() -> void:
	_cleanup_line()
	_cleanup_bobber()
	if casting_timer:
		casting_timer.stop()
	$FishManager.cleanup()


func reset_for_restart() -> void:
	_report_zone_leave()
	_cleanup_all()
	bite_timer.stop()
	current_state = State.IDLE
	hook_type = HookType.NONE
	_tether_target = null
	_is_fighting = false
	_escape_timer = 0.0
	_telegraph_intensity = 0.0
	_stop_telegraph()
	personal_catch_count = 0
	_active_zone_index = -1
	personal_catch_changed.emit(personal_catch_count)


func _snap_bobber_to_rod() -> void:
	if is_instance_valid(bobber_node):
		bobber_node.visible = true
		bobber_node.position = _get_rod_tip_position() + Vector3(0, -0.1, 0)
	_rebuild_line()


func _generate_rumble_stream() -> AudioStreamWAV:
	var duration: float = 0.35
	var sample_rate: int = 44100
	var sample_count: int = int(duration * sample_rate)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false

	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i in range(sample_count):
		var t: float = float(i) / float(sample_rate)

		var attack: float = min(t / 0.012, 1.0)
		var body: float = exp(-t * 8.0)
		var envelope: float = attack * body

		var tone1: float = sin(t * TAU * 220.0) * 0.35
		var tone2: float = sin(t * TAU * 330.0) * 0.25
		var tone3: float = sin(t * TAU * 440.0) * 0.15
		var tone4: float = sin(t * TAU * 550.0) * 0.08
		var low: float = tone1 + tone2 + tone3 + tone4

		var snap_env: float = clamp(1.0 - t / 0.025, 0.0, 1.0)
		var snap: float = randf_range(-1.0, 1.0) * snap_env * 0.3

		var sample: float = (low + snap) * envelope
		sample = clamp(sample, -1.0, 1.0)

		var s: int = clampi(int(sample * 16384), -32768, 32767)
		var offset: int = i * 2
		data[offset] = s & 0xFF
		data[offset + 1] = (s >> 8) & 0xFF

	wav.data = data
	return wav


func _generate_telegraph_stream() -> AudioStreamWAV:
	var duration: float = 1.0
	var sample_rate: int = 44100
	var sample_count: int = int(duration * sample_rate)

	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false

	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i in range(sample_count):
		var t: float = float(i) / float(sample_rate)

		var tone1: float = sin(t * TAU * 100.0) * 0.25
		var tone2: float = sin(t * TAU * 150.0) * 0.15
		var tone3: float = sin(t * TAU * 200.0) * 0.08

		var sample: float = tone1 + tone2 + tone3
		sample = clamp(sample, -1.0, 1.0)

		var s: int = clampi(int(sample * 16384), -32768, 32767)
		var offset: int = i * 2
		data[offset] = s & 0xFF
		data[offset + 1] = (s >> 8) & 0xFF

	wav.data = data
	return wav


func _on_catch_feedback_completed() -> void:
	if current_state == State.SUCCESS:
		_snap_bobber_to_rod()
		current_state = State.IDLE


func _get_owner_client_id() -> int:
	var parent_player := get_parent()
	if not (parent_player is Player):
		return -1
	if parent_player.spawn_index < game_manager.players.size():
		return game_manager.players[parent_player.spawn_index].id
	return -1


func _report_zone_enter(zone_index: int) -> void:
	if zone_index == -1:
		return
	_try_find_zone_manager()
	if not is_instance_valid(_zone_manager_ref):
		return
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_zone_manager_ref.enter_zone(zone_index)
	else:
		_zone_manager_ref.enter_zone.rpc(zone_index)


func _report_zone_leave() -> void:
	if _active_zone_index == -1:
		return
	_try_find_zone_manager()
	if not is_instance_valid(_zone_manager_ref):
		_active_zone_index = -1
		return
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_zone_manager_ref.leave_zone(_active_zone_index)
	else:
		_zone_manager_ref.leave_zone.rpc(_active_zone_index)
	_active_zone_index = -1


func get_debug_state() -> Dictionary:
	var hook_name: String = HookType.keys()[hook_type] if hook_type < HookType.size() else str(hook_type)
	var dist_text := "(none)"
	var caster := get_parent() as Player
	if hook_type == HookType.PLAYER and caster and is_instance_valid(caster) and is_instance_valid(_tether_target):
		dist_text = "%.2f" % caster.global_position.distance_to(_tether_target.global_position)
	return {
		"hook_type": hook_name,
		"tether_distance": dist_text,
		"fight_progress": round(_fight_progress * 100) / 100.0,
		"target_name": _tether_target.name if _tether_target and is_instance_valid(_tether_target) else "none"
	}


func get_debug_actions() -> Array[Dictionary]:
	return [
		{"id": "force_hook_player", "label": "Force Hook Player"},
		{"id": "pop_tether", "label": "Pop Tether"},
		{"id": "reset_fight", "label": "Reset Fight"}
	]


func debug_action(action_id: String) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	match action_id:
		"force_hook_player":
			_debug_force_hook_player()
		"pop_tether":
			_debug_pop_tether()
		"reset_fight":
			reset_for_restart()


func _debug_force_hook_player() -> void:
	if current_state != State.IDLE or hook_type != HookType.NONE or _is_fighting:
		return
	var caster := get_parent() as Player
	if not caster or not is_instance_valid(caster):
		return
	var root := get_tree().root.get_node_or_null("/root/main/Players")
	if not root:
		root = get_tree().root.find_child("Players", true, false)
	if not root:
		return
	for child in root.get_children():
		if child is Player:
			var candidate := child as Player
			if candidate != caster and is_instance_valid(candidate) and candidate.player_state == Player.PlayerState.FLOATING:
				_apply_predicted_player_hook(candidate)
				return


func _debug_pop_tether() -> void:
	if hook_type == HookType.NONE and not _is_fighting:
		return
	_on_hook_rejected()
	_notify_hook_end()
