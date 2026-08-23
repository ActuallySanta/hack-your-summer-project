extends Node2D

const battle_cry := preload("res://Sounds/Entities/Enemies/ContianmentDrone/CD_Announce.wav")
const yelp := preload("res://Sounds/Entities/Enemies/ContianmentDrone/CD_Hurt.wav")
const boss_death_sfx := preload("res://Sounds/Entities/Enemies/ContianmentDrone/Boss_Explosion.wav")

@export var left_tunnel_pos : Marker2D
@export var right_tunnel_pos : Marker2D
@export var node_to_drop_on_destroy : Node2D

@onready var big_gun := $BigGun
@onready var mini_gun := $MiniGunManager
@onready var bumper := $Bumper
@onready var health_component := $HealthComponent
@onready var exploder := $Exploder
@onready var vocalizer := $Vocalizer
@onready var motor := $Motor
@onready var animator := $Animator
@onready var prefightNodes := $PreFightNodes

var do_intro_cutscene : bool = true
var left_tunnel_global_pos : Vector2
var right_tunnel_global_pos : Vector2

func _ready() -> void:
	if GameManager.is_object_collected("Gun"):
		queue_free()
		return
	
	left_tunnel_global_pos = left_tunnel_pos.global_position
	right_tunnel_global_pos = right_tunnel_pos.global_position
	
	MusicManager.override_automatic_assignment( true )
	MusicManager.set_background_track_from_name("BOSS", "Ambiance")
	health_component.on_destroy_event.connect(flash_and_spawn_gun)
	health_component.on_death_event.connect(on_death)
	health_component.on_hit_event.connect(yelp_in_agony)

func on_death() -> void:
	exploder.start_explosions()
	MusicManager.try_mute_volume(name)
	motor.stop()
	motor.volume_db = -80
	vocalizer.stop()
	vocalizer.volume_db = -80

func yelp_in_agony() -> void:
	vocalizer.stream = yelp
	vocalizer.play()
	animator.play("damage_flash")
	if do_intro_cutscene:
		start_intro_cutscene()

func enter_tunnel(querry_mode: StringName) -> void:
	if querry_mode == "left":
		enter_left_tunnel()
	elif querry_mode == "right":
		enter_right_tunnel()
	elif querry_mode == "closest":
		var delta := left_tunnel_global_pos - global_position
		pass
	elif querry_mode == "opposite":
		#TODO
		pass
	else:
		pass
	

func enter_left_tunnel() -> void:
	pass

func enter_right_tunnel() -> void:
	pass

func start_intro_cutscene() -> void:
	health_component.ignore_effects = true

func leave_intro_cutscene() -> void:
	health_component.ignore_effects = false

func remove_visuals() -> void:
	big_gun.queue_free()
	mini_gun.queue_free()
	bumper.queue_free()
	exploder.queue_free()
	$BIGGUNStand.queue_free()
	$Wheels.queue_free()
	$Shell.queue_free()

func flash_and_spawn_gun() -> void:
	CameraEffects.flash(Color(1,1,1,0.5), 0.1, 0.075, 0.075, CameraEffects.Ease.EASE_OUT, CameraEffects.Ease.EASE_IN)
	CameraEffects.shake(12.0, 0.4, CameraEffects.Axis.BOTH, CameraEffects.Ease.EASE_IN)
	MusicManager.try_unmute_volume(name)
	MusicManager.set_background_track_from_name("NONE", "I can say whatever the fuck I want here heheheh")
	node_to_drop_on_destroy.global_position = global_position
	remove_visuals()
	$DeathExplosion.play()
	await vocalizer.finished
	queue_free()
