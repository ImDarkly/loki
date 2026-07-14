extends GutTest

class GatedParent extends Node:
	var gate_result: bool = false
	func can_interact(_interactor: Node) -> bool:
		return gate_result


var component


func before_each() -> void:
	var scene := load("res://systems/interactable/interactable_component.tscn")
	component = autofree(scene.instantiate())
	add_child(component)
	await get_tree().process_frame


func test_default_prompt_text() -> void:
	assert_eq(component.prompt_text, "Interact", "Default prompt_text should be 'Interact'")


func test_custom_prompt_text() -> void:
	component.prompt_text = "Open Shop"
	assert_eq(component.prompt_text, "Open Shop", "prompt_text should be settable")


func test_can_interact_default_true() -> void:
	assert_true(component.can_interact(Node.new()), "Default can_interact should return true")


func test_can_interact_delegates_to_parent() -> void:
	var parent: GatedParent = autofree(GatedParent.new())
	parent.gate_result = false
	var child: InteractableComponent = autofree(load("res://systems/interactable/interactable_component.tscn").instantiate())
	parent.add_child(child)
	add_child(parent)
	assert_false(child.can_interact(Node.new()), "Should delegate to parent and return false")


func test_interacted_signal_emitted_with_interactor() -> void:
	var mock_interactor := Node.new()
	add_child(mock_interactor)
	watch_signals(component)
	component.interacted.emit(mock_interactor)
	assert_signal_emitted(component, "interacted")
	assert_signal_emit_count(component, "interacted", 1)
