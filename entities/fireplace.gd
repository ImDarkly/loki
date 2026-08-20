extends StaticBody3D

@onready var interactable_component = $InteractableComponent
@onready var coin_manager = get_node_or_null("/root/main/CoinManager")
@onready var _flame_nodes: Array[Node3D] = [$FlameLow, $FlameMid, $FlameTip]
@onready var _seats_container: Node3D = $Seats
@onready var _seat_markers: Array[Node3D] = [$Seats/Seat1, $Seats/Seat2, $Seats/Seat3, $Seats/Seat4]

var _seat_occupants: Dictionary = {}


func _ready() -> void:
	interactable_component.interacted.connect(_on_interact)
	if coin_manager:
		coin_manager.fireplace_updated.connect(_update_fireplace_visuals)
	_update_fireplace_visuals()
	_update_prompt()


func _update_fireplace_visuals() -> void:
	var owned: bool = coin_manager != null and coin_manager.is_fireplace_owned()
	for flame in _flame_nodes:
		flame.visible = owned
	if _seats_container:
		_seats_container.visible = owned


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

	if player._sitting_heal and player._sitting_heal.is_sitting:
		release_seat_for_player(player)
		player.toggle_sitting()
	else:
		var seat := _find_available_seat()
		if seat:
			_seat_occupants[seat] = player
			player.assigned_fireplace = self
			player.assigned_fireplace_seat = seat
			player.global_transform = seat.global_transform
			player.toggle_sitting()


func _find_available_seat() -> Node3D:
	for seat in _seat_markers:
		if not _seat_occupants.has(seat) or not is_instance_valid(_seat_occupants[seat]) or not _seat_occupants[seat]._sitting_heal.is_sitting:
			return seat
	return null


func release_seat_for_player(player: Player) -> void:
	for seat in _seat_occupants.keys():
		if _seat_occupants[seat] == player:
			_seat_occupants.erase(seat)
	if player.assigned_fireplace == self:
		player.assigned_fireplace = null
		player.assigned_fireplace_seat = null