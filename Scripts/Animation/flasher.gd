class_name Flasher extends Node2D

@onready var _flash_anim := $AnimationPlayer

func flash() -> void:
	_flash_anim.play("flash")
