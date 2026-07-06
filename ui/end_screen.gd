extends CanvasLayer

@export var round_manager: Node3D
@export var quota_manager: Node3D

@onready var outcome_label: Label = $CenterPanel/VBox/OutcomeLabel
@onready var quota_label: Label = $CenterPanel/VBox/QuotaLabel


func _ready() -> void:
	if round_manager:
		round_manager.round_ended.connect(_on_round_ended)


func _on_round_ended(success: bool) -> void:
	outcome_label.text = "SUCCESS" if success else "QUOTA FAILED"

	if quota_manager and round_manager:
		quota_label.text = "%d / %d fish" % [quota_manager.shared_quota, round_manager.quota_target]

	visible = true
