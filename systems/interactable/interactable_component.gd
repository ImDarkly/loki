class_name InteractableComponent extends Node

signal interacted(interactor: Node)

@export var prompt_text: String = "Interact"


func can_interact(interactor: Node) -> bool:
	var parent := get_parent()
	if parent and parent.has_method("can_interact"):
		return parent.can_interact(interactor)
	return true
