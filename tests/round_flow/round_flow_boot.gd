extends Node


func _ready() -> void:
	var driver: Node = load("res://tests/round_flow/round_flow_driver.gd").new()
	get_tree().root.add_child.call_deferred(driver)