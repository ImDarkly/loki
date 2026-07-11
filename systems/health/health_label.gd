extends CanvasLayer

@onready var label: Label = $Label
@onready var health_component: HealthComponent = $"../HealthComponent"


func _ready() -> void:
	if health_component == null:
		label.text = "HP: ?/?"
		return
	label.text = "HP: %d/%d" % [health_component.current_health, health_component.max_health]
	health_component.health_changed.connect(_on_health_changed)


func _on_health_changed(old_value: int, new_value: int) -> void:
	label.text = "HP: %d/%d" % [new_value, health_component.max_health]
