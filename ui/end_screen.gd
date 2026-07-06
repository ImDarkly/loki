extends CanvasLayer

@onready var outcome_label: Label = $CenterPanel/VBox/OutcomeLabel
@onready var quota_label: Label = $CenterPanel/VBox/QuotaLabel


func _ready() -> void:
	var rm := get_node_or_null("/root/main/RoundManager")
	if rm:
		rm.round_ended.connect(_on_round_ended)


func _on_round_ended(success: bool) -> void:
	outcome_label.text = "SUCCESS" if success else "QUOTA FAILED"

	var qm := get_node_or_null("/root/main/QuotaManager")
	var rm := get_node_or_null("/root/main/RoundManager")
	if qm and rm:
		quota_label.text = "%d / %d fish" % [qm.shared_quota, rm.quota_target]

	visible = true
