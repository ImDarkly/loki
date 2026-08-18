extends Node3D

const SAMPLE_RATE := 48000
const FRAMES_PER_CHUNK := 480

var _room_name: String = ""
var _configured: bool = false
var _configured_authoritative: bool = false

var _notif_before_render: int = EOS.NotificationIdInvalid

var _generator: AudioStreamGenerator
var _playback: AudioStreamGeneratorPlayback

var _render_mutex := Mutex.new()
var _render_queue: Array = []


func _ready() -> void:
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = SAMPLE_RATE
	_generator.buffer_length = 0.1
	$AudioStreamPlayer3D.stream = _generator
	$AudioStreamPlayer3D.play()
	_playback = $AudioStreamPlayer3D.get_stream_playback() as AudioStreamGeneratorPlayback


func _process(delta: float) -> void:
	if not _configured:
		_setup()
		return
	_drain_render_queue()
	if _configured_authoritative:
		_send_audio_chunk(delta)


func _setup() -> void:
	if _configured:
		return
	if _room_name == "":
		if NetworkManager.lobby == null or NetworkManager.lobby.rtc_room_name.is_empty():
			return
		_room_name = NetworkManager.lobby.rtc_room_name

	_configured = true
	_configured_authoritative = is_multiplayer_authority()
	if not _configured_authoritative:
		return

	if not IEOS.rtc_audio_audio_before_render.is_connected(_on_audio_before_render):
		IEOS.rtc_audio_audio_before_render.connect(_on_audio_before_render)

	var render_opts := EOS.RTCAudio.AddNotifyAudioBeforeRenderOptions.new()
	render_opts.local_user_id = HAuth.product_user_id
	render_opts.room_name = _room_name
	render_opts.unmixed_audio = true
	_notif_before_render = EOS.RTCAudio.RTCAudioInterface.add_notify_audio_before_render(render_opts)


func _send_audio_chunk(_delta: float) -> void:
	if _room_name == "":
		return
	var mic := get_parent().get_node_or_null("VoiceChatManager")
	if mic == null or not mic.has_method("get_frames_available"):
		return
	# Manual audio input has no SDK capture pipeline, so AddNotifyAudioBeforeSend never fires.
	# Poll the capture in fixed 10 ms chunks (matching the EOSG reference sample) instead.
	while mic.get_frames_available() >= FRAMES_PER_CHUNK:
		var captured: PackedVector2Array = mic.get_captured_frames(FRAMES_PER_CHUNK)
		if captured.size() == 0:
			return
		var frames := _captured_to_send_frames(captured, FRAMES_PER_CHUNK)
		var opts := EOS.RTCAudio.SendAudioOptions.new()
		opts.local_user_id = HAuth.product_user_id
		opts.room_name = _room_name
		opts.frames = frames
		opts.sample_rate = SAMPLE_RATE
		opts.channels = 1
		EOS.RTCAudio.RTCAudioInterface.send_audio(opts)


func _on_audio_before_render(data: Dictionary) -> void:
	var participant_id: String = data.get("participant_id", "")
	if participant_id == "" or participant_id == HAuth.product_user_id:
		return
	var buffer: Dictionary = data.get("buffer", {})
	var frames: Array = buffer.get("frames", [])
	if frames.is_empty():
		return
	var channels: int = buffer.get("channels", 1)
	var sample_rate: int = buffer.get("sample_rate", SAMPLE_RATE)
	# EOS delivers this callback on a worker thread; queue for the main thread.
	_render_mutex.lock()
	_render_queue.append({"participant_id": participant_id, "frames": frames, "channels": channels, "sample_rate": sample_rate})
	_render_mutex.unlock()


func _drain_render_queue() -> void:
	_render_mutex.lock()
	var pending := _render_queue.duplicate()
	_render_queue.clear()
	_render_mutex.unlock()
	for item in pending:
		_route_render(item)


func _route_render(item: Dictionary) -> void:
	var peer := NetworkManager.peer
	# NetworkManager.peer is the EOSG addon's MultiplayerPeer subclass, whose
	# get_peer_id is an addon-specific extension (not part of Godot's base API),
	# so we guard by has_method rather than static typing.
	if peer == null or not peer.has_method("get_peer_id"):
		return
	var target_id: int = peer.get_peer_id(item.participant_id)
	if target_id <= 0:
		return
	var players := get_node_or_null("/root/main/Players")
	if players == null:
		return
	var target := players.get_node_or_null("Player_%d" % target_id)
	if target == null:
		return
	var sink := target.get_node_or_null("VoiceChatNetwork")
	if sink == null or not sink.has_method("push_audio"):
		return
	sink.push_audio(item.frames, item.sample_rate, item.channels)


func push_audio(frames: Array, _sample_rate: int, channels: int) -> void:
	if _playback == null:
		return
	var out := _frames_to_push_data(frames, channels)
	for f in out:
		if not _playback.push_frame(f):
			break


func _captured_to_send_frames(captured: PackedVector2Array, count: int) -> PackedInt32Array:
	var frames := PackedInt32Array()
	frames.resize(count)
	for i in count:
		if i < captured.size():
			var v := (captured[i].x + captured[i].y) * 0.5
			frames[i] = clampi(int(round(v * 32767.0)), -32768, 32767)
		else:
			frames[i] = 0
	return frames


func _frames_to_push_data(frames: Array, channels: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	if channels >= 2:
		var i := 0
		while i + 1 < frames.size():
			out.append(Vector2(float(frames[i]) / 32768.0, float(frames[i + 1]) / 32768.0))
			i += 2
	else:
		var v := Vector2.ZERO
		for f in frames:
			v = Vector2(float(f) / 32768.0, float(f) / 32768.0)
			out.append(v)
	return out


func _exit_tree() -> void:
	if _notif_before_render != EOS.NotificationIdInvalid:
		EOS.RTCAudio.RTCAudioInterface.remove_notify_audio_before_render(_notif_before_render)
		_notif_before_render = EOS.NotificationIdInvalid
	if IEOS.rtc_audio_audio_before_render.is_connected(_on_audio_before_render):
		IEOS.rtc_audio_audio_before_render.disconnect(_on_audio_before_render)