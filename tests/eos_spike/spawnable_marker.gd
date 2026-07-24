extends Node3D


func _ready() -> void:
	var sync := $Synchronizer as MultiplayerSynchronizer
	if sync:
		sync.add_property("position")
