extends StaticBody3D

@onready var interactable_component = $InteractableComponent
@onready var _count_label: Label3D = $CountLabel
@onready var _quota_manager: Node3D = get_node_or_null("/root/main/QuotaManager")


func _ready() -> void:
	_update_label()
	if _quota_manager and _quota_manager.has_signal("quota_updated"):
		_quota_manager.quota_updated.connect(_on_quota_updated)


func _on_quota_updated(_value: int) -> void:
	_update_label()


func _update_label() -> void:
	if not _count_label:
		return
	var count: int = 0
	if _quota_manager and "shared_quota" in _quota_manager:
		count = _quota_manager.shared_quota
	_count_label.text = "%d fish in storage" % count
