extends Node2D

const battle_cry := preload("res://Sounds/Entities/Enemies/ContianmentDrone/CD_Announce.wav")
const yelp := preload("res://Sounds/Entities/Enemies/ContianmentDrone/CD_Hurt.wav")
const boss_death_sfx := preload("res://Sounds/Entities/Enemies/ContianmentDrone/Boss_Explosion.wav")

@export var left_tunnel_pos : Marker2D
@export var right_tunnel_pos : Marker2D
@export var node_to_drop_on_destroy : Node2D
@export var acceleration_px_per_ss : float
@export var max_velocity : float
@export var anim_speed_adjust : float:
	set(value):
		anim_speed_adjust = value
		big_gun.anim_speed_adjust = value
		mini_gun.anim_speed_adjust = value
		wheels.anim_speed_adjust = value
		shell.anim_speed_adjust = value
		gun_stand.anim_speed_adjust = value
		bumper.anim_speed_adjust = value

@export var pause_sprite_animations : bool:
	set(value):
		pause_sprite_animations = value
		big_gun.make_paused(value)
		mini_gun.make_paused(value)
		wheels.make_paused(value)
		shell.make_paused(value)
		gun_stand.make_paused(value)
		bumper.make_paused(value)

@onready var visuals := $FaderNode/Visuals
@onready var wheels := $FaderNode/Visuals/Wheels
@onready var shell := $FaderNode/Visuals/Shell
@onready var gun_stand := $FaderNode/Visuals/BIGGUNStand
@onready var big_gun := $FaderNode/Visuals/BigGun
@onready var mini_gun := $FaderNode/Visuals/MiniGunManager
@onready var bumper := $FaderNode/Visuals/Bumper
@onready var health_component := $HealthComponent
@onready var exploder := $Exploder
@onready var vocalizer := $Vocalizer
@onready var motor := $Motor
@onready var animator := $Animator
@onready var prefightNodes := $PreFightNodes

var do_intro_cutscene : bool = true
var left_tunnel_global_pos : float
var right_tunnel_global_pos : float
var target_tunnel : StringName = "Left"
var target_tunnel_to_glo_pos : Dictionary[ StringName, float ]
var velocity : float = 0.0

enum state{
	INTRO,
	NAV_TUNNEL,
	ENTER_TUNNEL,
	CHOOSE_ATTACK,
	PERFORM_ATTACK_CHARGE,
	PERFORM_ATTACK_CHARGE_GUN,
	PERFORM_ATTACK_MINIGUN,
	DIE,
}
var behavior : state = state.INTRO

#region Update Behaviors
func _process(delta: float) -> void:
	match behavior:
		state.INTRO:
			return
		state.DIE:
			return
		state.NAV_TUNNEL:
			_on_nav_tunnel(delta)
		state.ENTER_TUNNEL:
			_on_enter_tunnel(delta)
		state.CHOOSE_ATTACK:
			_on_choose_attack(delta)
		state.PERFORM_ATTACK_CHARGE:
			_on_attack_charge(false)
		state.PERFORM_ATTACK_CHARGE_GUN:
			_on_attack_charge(true)
		state.PERFORM_ATTACK_MINIGUN:
			_on_attack_mini_gun()

func _on_nav_tunnel(delta: float) -> void:
	if (target_tunnel == "LEFT" and left_tunnel_global_pos >= global_position.x) or (target_tunnel == "RIGHT" and left_tunnel_global_pos <= global_position.x):
		behavior = state.ENTER_TUNNEL
		return
	
	var amount = acceleration_px_per_ss * delta
	if target_tunnel == "LEFT":
		amount *= -1
	
	velocity += amount
	if abs(velocity) >= max_velocity:
		velocity = max_velocity if target_tunnel == "Left" else -max_velocity
	global_position.x += velocity

func _on_enter_tunnel(delta:float) -> void:
	if animator.is_playing():
		return
	animator.play("fade_out")
	behavior = state.CHOOSE_ATTACK

func _on_choose_attack(delta: float) -> void:
	pass

func _on_attack_charge(use_big_gun: bool) -> void:
	pass

func _on_attack_mini_gun() -> void:
	pass

#endregion

func _ready() -> void:
	if GameManager.is_object_collected("Gun"):
		queue_free()
		return
	
	left_tunnel_global_pos = left_tunnel_pos.global_position.x
	right_tunnel_global_pos = right_tunnel_pos.global_position.x
	target_tunnel_to_glo_pos = { "LEFT": left_tunnel_global_pos, "RIGHT": right_tunnel_global_pos }
	
	MusicManager.override_automatic_assignment( true )
	MusicManager.set_background_track_from_name("BOSS", "Ambiance")
	
	health_component.on_destroy_event.connect(flash_and_spawn_gun)
	health_component.on_death_event.connect(on_death)
	health_component.on_hit_event.connect(yelp_in_agony)
	
	pause_sprite_animations = true

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
	visuals.flash()
	if do_intro_cutscene:
		start_intro_cutscene()

func enter_tunnel(querry_mode: StringName) -> void:
	if querry_mode == "left":
		enter_left_tunnel()
	elif querry_mode == "right":
		enter_right_tunnel()
	elif querry_mode == "closest":
		var delta_l := left_tunnel_global_pos - global_position.x
		if delta_l < right_tunnel_global_pos - global_position.x:
			enter_left_tunnel()
		else:
			enter_right_tunnel()

func enter_left_tunnel() -> void:
	animator.play("accelerate")
	behavior = state.NAV_TUNNEL
	target_tunnel = "LEFT"
	velocity = 0.0

func enter_right_tunnel() -> void:
	animator.play("accelerate")
	behavior = state.NAV_TUNNEL
	target_tunnel = "RIGHT"
	velocity = 0.0

func start_intro_cutscene() -> void:
	if not do_intro_cutscene:
		return
	
	health_component.ignore_effects = true
	enter_tunnel("closest")
	MusicManager.set_background_track_from_name("NONE", "I can say whatever the fuck I want here heheheh")
	
	# Temp timer to get around lack of intro cutscene
	await get_tree().create_timer(1.0).timeout
	leave_intro_cutscene()

func leave_intro_cutscene() -> void:
	do_intro_cutscene = false
	health_component.ignore_effects = false
	vocalizer.stream = battle_cry
	vocalizer.volume_db = 10
	vocalizer.play()
	CameraEffects.shake(17, 1.4, CameraEffects.Axis.BOTH, CameraEffects.Ease.EASE_IN_OUT)
	await vocalizer.finished
	vocalizer.volume_db = 0.0
	MusicManager.set_background_track_from_name("BOSS", "Containment Drone")

func remove_visuals() -> void:
	$FaderNode.queue_free()

func flash_and_spawn_gun() -> void:
	CameraEffects.flash(Color(1,1,1,0.5), 0.1, 0.075, 0.075, CameraEffects.Ease.EASE_OUT, CameraEffects.Ease.EASE_IN)
	CameraEffects.shake(12.0, 0.4, CameraEffects.Axis.BOTH, CameraEffects.Ease.EASE_IN)
	MusicManager.try_unmute_volume(name)
	MusicManager.set_background_track_from_name("NONE", "I can say whatever the fuck I want here heheheh")
	node_to_drop_on_destroy.global_position = global_position
	remove_visuals()
	
	var deathsfx : AudioStreamPlayer2D = $DeathExplosion
	deathsfx.play()
	exploder.end_explosions()
	await exploder.when_no_explosions_left
	if deathsfx.playing == true:
		await deathsfx.finished
		queue_free()
	else:
		queue_free()
	
