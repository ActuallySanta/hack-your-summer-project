extends Node2D

const battle_cry := preload("res://Sounds/Entities/Enemies/ContianmentDrone/CD_Announce.wav")
const yelp := preload("res://Sounds/Entities/Enemies/ContianmentDrone/CD_Hurt.wav")

@export var node_to_drop_on_destroy : Node2D

@onready var big_gun := $BigGun
@onready var mini_gun := $MiniGunManager
@onready var bumper := $Bumper
@onready var health_component := $HealthComponent
@onready var exploder := $Exploder
@onready var vocalizer := $Vocalizer
@onready var motor := $Motor

func _ready() -> void:
	if GameManager.is_object_collected("Gun"):
		queue_free()
		return
	
	MusicManager.override_automatic_assignment( true )
	MusicManager.set_background_track_from_name("BOSS", "Ambiance")
	health_component.on_destroy_event.connect(flash_and_spawn_gun)
	health_component.on_death_event.connect(on_death)

func on_death() -> void:
	exploder.start_explosions()
	MusicManager.try_mute_volume(name)
	motor.stop()
	motor.volume_db = -80
	vocalizer.stop()
	vocalizer.volume_db = -80

func flash_and_spawn_gun() -> void:
	MusicManager.try_unmute_volume(name)
	MusicManager.set_background_track_from_name("NONE", "I can say whatever the fuck I want here heheheh")
	node_to_drop_on_destroy.global_position = global_position
	queue_free()
