extends Node2D

@onready var big_gun := $BigGun
@onready var mini_gun := $MiniGunManager
@onready var bumper := $Bumper
@onready var health_component := $HealthComponent
@onready var exploder := $Exploder

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	exploder.start_explosions()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
