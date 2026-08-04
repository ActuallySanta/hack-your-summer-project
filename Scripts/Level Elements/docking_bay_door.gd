extends Node2D

@onready var sprite : Sprite2D = $Sprite2D
@onready var collider : StaticBody2D = $StaticBody2D
@onready var animator : AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	if GameManager.is_station_powered():
		immediate_open()
	else:
		GlobalSignals.RestoreStationPower.connect(animate_open)


func animate_open() -> void:
	collider.process_mode = Node.PROCESS_MODE_DISABLED
	animator.play("open")

func immediate_open() -> void:
	collider.process_mode = Node.PROCESS_MODE_DISABLED
	sprite.frame = 5
