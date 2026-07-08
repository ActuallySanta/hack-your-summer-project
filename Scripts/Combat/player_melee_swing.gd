class_name PlayerMeleeSwing
extends Node2D

@export var lifetime := 0.5

var _lifetime_timer : float

func _ready() -> void:
	_lifetime_timer = lifetime
	$AnimatedSprite2D.play("default")

func _physics_process(delta: float) -> void:
	_lifetime_timer -= delta
	if _lifetime_timer <= 0:
		queue_free()
