extends StaticBody3D

@onready var interactable_component = $InteractableComponent
@onready var coin_manager = get_node_or_null("/root/main/CoinManager")


func _ready() -> void:
	interactable_component.interacted.connect(_on_interact)
	_update_prompt()


func _process(_delta: float) -> void:
	_update_prompt()


func _update_prompt() -> void:
	if not coin_manager:
		return
	if not coin_manager.is_fireplace_owned():
		interactable_component.is_enabled = false
	else:
		interactable_component.prompt_text = "Sit by the Fireplace [Right-click]"
		interactable_component.prompt_color = Color.WHITE
		interactable_component.is_enabled = true


func _on_interact(player: Player) -> void:
	if not coin_manager or not coin_manager.is_fireplace_owned():
		return
	if player.player_state == Player.PlayerState.SPECTATE:
		return
	player.toggle_sitting()