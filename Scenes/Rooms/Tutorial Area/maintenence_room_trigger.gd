extends Node2D

@onready var dialogue_trigger: Area2D = $DialogueTrigger


func _on_access_button_on_button_interact() -> void:
	dialogue_trigger.monitoring = true
