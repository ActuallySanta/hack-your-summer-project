extends Node

signal item_collected(itemName: String)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func collect_item(itemName: String):
	item_collected.emit(itemName)
