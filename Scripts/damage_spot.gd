class_name DamageSpot
extends Node2D

@onready var hitbox := $Hitbox as Hitbox

func _physics_process(delta: float) -> void:
	hitbox.reset() #reset hitbox every frame so it can re-hit entities
