extends Node

@onready var _mic: Node = $TwoVoipMic
@onready var _speaker: Node = $AudioStreamPlayer/TwoVoipSpeaker

var _mic_initialized: bool = false


func _enter_tree() -> void:
	var opus_stream := AudioStreamOpus.new()
	opus_stream.resource_local_to_scene = true
	$AudioStreamPlayer.stream = opus_stream


func _ready() -> void:
	_mic.transmitaudiopacket.connect(_on_mic_audio_packet)
	_mic.transmitaudiojsonpacket.connect(_on_mic_json_packet)
	if is_multiplayer_authority():
		_enable_mic()


func _enable_mic() -> void:
	if _mic_initialized:
		return

	var mic_btn := Button.new()
	mic_btn.toggle_mode = true

	var ptt_btn := Button.new()

	var vox_btn := Button.new()
	vox_btn.toggle_mode = true
	vox_btn.button_pressed = true

	var denoise_btn := Button.new()

	var device_sel := OptionButton.new()

	var mat := ShaderMaterial.new()

	_mic.initvoipmic(mic_btn, device_sel, ptt_btn, vox_btn, denoise_btn, mat)
	_mic.setopusvalues(48000, 20, 2, 12000, 5, true)
	_mic.set_voxthreshhold(0.01)

	mic_btn.button_pressed = true
	mic_btn.toggled.emit(true)

	_mic.process_mode = Node.PROCESS_MODE_INHERIT
	_mic_initialized = true
	print("VOICE: mic enabled, authority=", is_multiplayer_authority())


func _on_mic_audio_packet(opus_packet: PackedByteArray, _frame_count: int) -> void:
	send_voice_packet.rpc(opus_packet)


func _on_mic_json_packet(data: Dictionary) -> void:
	send_voice_packet.rpc(JSON.stringify(data).to_ascii_buffer())


@rpc("any_peer", "unreliable", "call_remote")
func send_voice_packet(packet: PackedByteArray) -> void:
	if _speaker:
		_speaker.tv_incomingaudiopacket(packet)
