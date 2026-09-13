class_name PlayerInteractable extends Area2D

@onready var image_controller := $"Image controller"

var _player_in_interactable

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _process(delta: float) -> void:
	if not _player_in_interactable:
		return


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_interactable = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_interactable = false
