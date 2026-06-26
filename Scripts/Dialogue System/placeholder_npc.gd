class_name NPC
extends Node2D

@onready var in_range_indicator: Polygon2D = $"In Range Indicator"

func _on_dialogue_trigger_body_entered(body: Node2D) -> void:
	if(body is Player):
		in_range_indicator.visible = true


func _on_dialogue_trigger_body_exited(body: Node2D) -> void:
	if(body is Player):
		in_range_indicator.visible = false
