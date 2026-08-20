extends StaticBody3D

@onready var interactable_component = $InteractableComponent
@onready var coin_manager = get_node_or_null("/root/main/CoinManager")
@onready var _flame_nodes: Array[Node3D] = [$FlameLow, $FlameMid, $FlameTip]


func _ready() -> void:
	interactable_component.interacted.connect(_on_interact)
	if coin_manager:
		coin_manager.fireplace_updated.connect(_update_flames)
	_update_flames()
	_update_prompt()


func _update_flames() -> void:
	var burning: bool = coin_manager != null and coin_manager.is_fireplace_owned()
	for flame in _flame_nodes:
		flame.visible = burning


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