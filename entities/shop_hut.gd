extends StaticBody3D

@onready var interactable_component = $InteractableComponent
@onready var round_manager = get_node("/root/main/RoundManager")

func _ready() -> void:
	interactable_component.interacted.connect(_on_interact)
	_update_prompt()

func _process(_delta: float) -> void:
	_update_prompt()

func _update_prompt() -> void:
	if round_manager.fishing_active:
		interactable_component.prompt_text = "Shop opens after fishing ends"
		interactable_component.prompt_color = Color.RED
		interactable_component.is_enabled = false
	else:
		interactable_component.prompt_text = "[Right-click] Open Shop"
		interactable_component.prompt_color = Color.WHITE
		interactable_component.is_enabled = true

func _on_interact(player: Player) -> void:
	if round_manager.fishing_active or player.player_state == Player.PlayerState.SPECTATE:
		return
	
	var shop_ui = preload("res://ui/shop_ui.tscn").instantiate()
	get_tree().root.add_child(shop_ui)
