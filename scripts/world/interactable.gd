class_name Interactable
extends Area3D

signal interacted(player: Node3D)

@export var prompt_text: String = "按 E 交互"
@export var enabled: bool = true

func interact(player: Node3D) -> void:
	if enabled:
		interacted.emit(player)
