extends StaticBody3D

@onready var _interactable: InteractableComponent = $InteractableComponent


func _ready() -> void:
	_interactable.interacted.connect(_on_interacted)


func can_interact(interactor: Node) -> bool:
	return interactor is Player and interactor.is_carrying


func _on_interacted(interactor: Node) -> void:
	if can_interact(interactor):
		interactor.deposit_carried_fish()
