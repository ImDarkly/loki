extends CanvasLayer

@export var voice_chat_manager_path: NodePath = NodePath("../VoiceChatManager")
@export var falloff_time: float = 0.3

var _target_db: float = -INF
var _display_db: float = -INF
var _is_yelling: bool = false

@onready var meter_fill: ColorRect = %MeterFill
@onready var meter_frame: Control = %MeterFrame
@onready var db_label: Label = %DBLabel
@onready var yell_label: Label = %YellLabel
@onready var mic_dot: ColorRect = %MicDot
@onready var voice_chat: Node = get_node_or_null(voice_chat_manager_path)


func _ready() -> void:
	if voice_chat == null:
		push_warning("MicLevelBar: VoiceChatManager not found")
		return

	if voice_chat.has_signal("mic_level_updated"):
		voice_chat.mic_level_updated.connect(_on_mic_level_updated)
	if voice_chat.has_signal("yelling_state_changed"):
		voice_chat.yelling_state_changed.connect(_on_yelling_state_changed)

	mic_dot.color = Color(0.3, 0.8, 0.3)

	_read_thresholds_and_add_zones()


func _read_thresholds_and_add_zones() -> void:
	var on_threshold: float = voice_chat.amplitude_threshold_on if voice_chat != null and "amplitude_threshold_on" in voice_chat else -12.0
	var off_threshold: float = voice_chat.amplitude_threshold_off if voice_chat != null and "amplitude_threshold_off" in voice_chat else -14.0
	var on_norm := clampf(_db_to_normalized(on_threshold), 0.0, 1.0)
	var off_norm := clampf(_db_to_normalized(off_threshold), 0.0, 1.0)

	var green := ColorRect.new()
	green.color = Color(0.0, 0.8, 0.0, 0.12)
	_add_zone(green, 0.0, off_norm)

	var yellow := ColorRect.new()
	yellow.color = Color(1.0, 0.8, 0.0, 0.12)
	_add_zone(yellow, off_norm, on_norm)

	var red := ColorRect.new()
	red.color = Color(1.0, 0.2, 0.0, 0.12)
	_add_zone(red, on_norm, 1.0)


func _add_zone(rect: ColorRect, norm_start: float, norm_end: float) -> void:
	rect.anchor_left = 0.0
	rect.anchor_top = 1.0 - norm_end
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0 - norm_start
	rect.offset_left = 0.0
	rect.offset_top = 0.0
	rect.offset_right = 0.0
	rect.offset_bottom = 0.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter_frame.add_child(rect)
	meter_frame.move_child(rect, 1)


func _on_mic_level_updated(level_db: float) -> void:
	_target_db = level_db


func _on_yelling_state_changed(is_yelling: bool) -> void:
	_is_yelling = is_yelling
	yell_label.visible = is_yelling


func _process(delta: float) -> void:
	if _target_db == -INF:
		_display_db = -INF
	elif _target_db > _display_db:
		_display_db = _target_db
	else:
		var decay := exp(-delta / falloff_time)
		_display_db = _target_db + (_display_db - _target_db) * decay

	_update_display()


func _update_display() -> void:
	var normalized := _db_to_normalized(_display_db)

	var frame_h := meter_frame.size.y
	if frame_h <= 0:
		frame_h = 200.0

	var fill_h := frame_h * normalized
	meter_fill.offset_top = frame_h - fill_h

	db_label.text = "%+.1f dB" % _display_db if _display_db > -INF else "-∞ dB"

	mic_dot.color = Color(0.3, 0.8, 0.3) if _display_db > -INF else Color(0.4, 0.4, 0.4)

	if _is_yelling:
		meter_fill.color = Color(1.0, 0.2, 0.0)
		return

	var on_threshold: float = -6.0
	var off_threshold: float = -8.0
	if voice_chat != null:
		if "amplitude_threshold_on" in voice_chat:
			on_threshold = voice_chat.amplitude_threshold_on
		if "amplitude_threshold_off" in voice_chat:
			off_threshold = voice_chat.amplitude_threshold_off

	if _display_db >= on_threshold:
		meter_fill.color = Color(1.0, 0.2, 0.0)
	elif _display_db >= off_threshold:
		meter_fill.color = Color(1.0, 0.8, 0.0)
	else:
		meter_fill.color = Color(0.0, 0.8, 0.0)


func _db_to_normalized(db: float) -> float:
	if db <= -60.0 or db == -INF:
		return 0.0
	if db >= 0.0:
		return 1.0
	return (db + 60.0) / 60.0
