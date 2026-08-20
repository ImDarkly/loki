class_name NotificationLabel extends CanvasLayer

const SHOW_TIME: float = 2.5

var _label: Label
var _tween: Tween


func _ready() -> void:
	_label = $Label
	_label.modulate.a = 0.0
	_label.visible = false


func show_message(text: String) -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_label.text = text
	_label.visible = true
	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", 1.0, 0.2)
	_tween.tween_interval(SHOW_TIME)
	_tween.tween_property(_label, "modulate:a", 0.0, 0.4)
	_tween.tween_callback(_hide_label)


func _hide_label() -> void:
	_label.visible = false