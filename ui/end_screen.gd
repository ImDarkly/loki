extends CanvasLayer

@onready var outcome_label: Label = $CenterPanel/VBox/OutcomeLabel
@onready var quota_label: Label = $CenterPanel/VBox/QuotaLabel
@onready var restart_button: Button = $CenterPanel/VBox/RestartButton
@onready var wait_label: Label = $CenterPanel/VBox/WaitLabel


func _ready() -> void:
	var rm := get_node_or_null("/root/main/RoundManager")
	if rm:
		rm.round_ended.connect(_on_round_ended)
	restart_button.pressed.connect(_on_restart_pressed)


func _on_round_ended(success: bool) -> void:
	outcome_label.text = "SUCCESS" if success else "QUOTA FAILED"

	var qm := get_node_or_null("/root/main/QuotaManager")
	if qm:
		quota_label.text = "%d fish caught" % qm.shared_quota

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	restart_button.visible = game_manager.is_server()
	wait_label.visible = not game_manager.is_server()
	visible = true


func _on_restart_pressed() -> void:
	var rm := get_node_or_null("/root/main/RoundManager")
	if rm:
		rm.restart_round()
