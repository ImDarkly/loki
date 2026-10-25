extends StaticBody3D

@onready var interactable_component = $InteractableComponent
@onready var round_manager = get_node_or_null("/root/main/RoundManager")

func _ready() -> void:
	_setup_visual()
	interactable_component.interacted.connect(_on_interact)
	_update_prompt()

func _setup_visual() -> void:
	var path := "res://entities/shop/assets/kenney_miniforest/building-roof.glb"
	if not ResourceLoader.exists(path):
		push_warning("Shop canopy missing or unimported: install Kenney Mini Forest building-roof.glb per ASSETS.md, then import in Godot.")
		return
	var scene := load(path) as PackedScene
	if scene == null or not scene.can_instantiate():
		push_warning("Optional prop is not a PackedScene: %s" % path)
		return
	var instance := scene.instantiate()
	var model := instance as Node3D
	if model == null:
		instance.free()
		push_warning("Optional prop has no Node3D root: %s" % path)
		return
	model.name = "Canopy"
	model.scale = Vector3.ONE * 2.2
	model.position.y = -1.0
	$Mesh.add_child(model)
	var root_mesh := model as MeshInstance3D
	var has_visible_mesh := root_mesh != null and root_mesh.mesh != null and root_mesh.mesh.get_surface_count() > 0 and root_mesh.is_visible_in_tree()
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh != null and mesh.mesh.get_surface_count() > 0 and mesh.is_visible_in_tree():
			has_visible_mesh = true
			break
	if not has_visible_mesh:
		model.free()
		push_warning("Optional prop has no visible mesh: %s" % path)
		return
	$Mesh/Fallback.free()

func _process(_delta: float) -> void:
	_update_prompt()

func _update_prompt() -> void:
	if round_manager == null:
		return
	if round_manager.fishing_active:
		interactable_component.prompt_text = "Shop opens after fishing ends"
		interactable_component.prompt_color = Color.RED
		interactable_component.is_enabled = false
	else:
		interactable_component.prompt_text = "[Right-click] Open Shop"
		interactable_component.prompt_color = Color.WHITE
		interactable_component.is_enabled = true

func _on_interact(player: Player) -> void:
	if round_manager == null:
		return
	if round_manager.fishing_active or player.player_state == Player.PlayerState.SPECTATE:
		return
	
	var shop_ui = preload("res://ui/shop_ui.tscn").instantiate()
	get_tree().root.add_child(shop_ui)
