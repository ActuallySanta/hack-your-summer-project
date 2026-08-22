extends Node2D

@export var node_to_drop_on_destroy : Node2D

@onready var big_gun := $BigGun
@onready var mini_gun := $MiniGunManager
@onready var bumper := $Bumper
@onready var health_component := $HealthComponent
@onready var exploder := $Exploder

func _ready() -> void:
	health_component.on_destroy_event.connect(flash_and_spawn_gun)
	health_component.on_death_event.connect(exploder.start_explosions)

func flash_and_spawn_gun() -> void:
	node_to_drop_on_destroy.global_position = global_position
	
	queue_free()
