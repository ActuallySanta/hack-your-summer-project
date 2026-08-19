class_name DoorTrigger extends Node2D

@export var doors_to_open : Door

func open_doors() -> void:
	for door in doors_to_open:
		door.animate_open()
