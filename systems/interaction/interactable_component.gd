class_name InteractableComponent
extends Node

signal interacted(player: Player)

@export var prompt_text: String = "Interact"
@export var prompt_color: Color = Color.WHITE
@export var is_enabled: bool = true
@export var show_prompt_without_carrying: bool = false
