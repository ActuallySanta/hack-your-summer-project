extends Node2D

const battle_cry := preload("res://Sounds/Entities/Enemies/ContianmentDrone/CD_Announce.wav")
const yelp := preload("res://Sounds/Entities/Enemies/ContianmentDrone/CD_Hurt.wav")
const boss_death_sfx := preload("res://Sounds/Entities/Enemies/ContianmentDrone/Boss_Explosion.wav")

const WHEEL_STOP_SPEED := 1.0

@export var left_tunnel_pos : Marker2D
@export var right_tunnel_pos : Marker2D
@export var node_to_drop_on_destroy : Node2D
@export var intro_collider : Area2D
@export_group("Attack")
@export var chances_for_attack : Dictionary[ StringName, float ] = {
	"CHARGE": 0.49,
	"CHARGE_LASER": 0.01,
	"MINIGUN": 0.50,
}
@export var max_speed_when_charging : float
@export var navigator_force_maximum_when_charging : float
@export var max_speed_when_escaping : float
@export var max_laser_time : float = 5.0
@export var min_laser_time : float = 1.0
@export var num_bullets_mingun_shoot : int = 5

@export_category("Export for anim, no use in inspector")
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

@onready var sprite_sheet_swapper := $FaderNode
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
@onready var navigator := $Navigator
# Hit/Hurt Colliders
@onready var hurtbox := $HealthComponent/Hurtbox
@onready var hitbox := $Hitbox

var is_dead : bool = false
var do_intro_cutscene : bool = true
var left_tunnel_global_pos : float
var right_tunnel_global_pos : float
var do_random_big_laser_shot : bool
var alt_shoot_timer: float
var bullets_to_fire : int
var _last_wheel_pos : Vector2
var destination_tunnel : StringName:
	set(value):
		destination_tunnel = value
		if value == "LEFT":
			navigator.node_to_go_to = left_tunnel_pos
		elif value == "RIGHT":
			navigator.node_to_go_to = right_tunnel_pos
var is_in_background : bool:
	set(value):
		is_in_background = value
		if is_instance_valid(hurtbox):
			hurtbox.ignore_hits = value
		if is_instance_valid(hitbox):
			hitbox.ignore_hits = value

enum state {
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
	_update_wheel_spin(delta)
	if is_dead:
		return
	match behavior:
		state.INTRO:
			return
		state.DIE:
			return
		state.NAV_TUNNEL:
			_on_nav_tunnel()
		state.ENTER_TUNNEL:
			_on_enter_tunnel()
		state.CHOOSE_ATTACK:
			_on_choose_attack( )
		state.PERFORM_ATTACK_CHARGE:
			_on_attack_charge(false)
		state.PERFORM_ATTACK_CHARGE_GUN:
			_on_attack_charge(true)
		state.PERFORM_ATTACK_MINIGUN:
			_on_attack_mini_gun()

## Nothing ever re-paused the wheels once an animation unpaused them, so they
## kept turning while the drone sat still. Tie them to how far it actually
## moved instead -- that holds no matter what does the moving.
func _update_wheel_spin(delta: float) -> void:
	if not is_instance_valid(wheels):
		return
	
	var speed := global_position.distance_to(_last_wheel_pos) / maxf(delta, 0.0001)
	_last_wheel_pos = global_position
	wheels.make_paused(pause_sprite_animations or speed < WHEEL_STOP_SPEED)

func _on_nav_tunnel() -> void:
	if (destination_tunnel == "LEFT" and left_tunnel_global_pos >= global_position.x) or (destination_tunnel == "RIGHT" and right_tunnel_global_pos <= global_position.x):
		navigator.node_to_go_to = null
		behavior = state.ENTER_TUNNEL
		return

func _on_enter_tunnel() -> void:
	if animator.is_playing():
		return
	
	do_random_big_laser_shot = false
	big_gun.turn_on_barrel()
	is_in_background = true
	animator.play("fade_out")
	behavior = state.CHOOSE_ATTACK

func _on_choose_attack() -> void:
	if animator.is_playing():
		return
	
	navigator.ignore_target = true
	set_navigator_speeds()
	var choose_side := "LEFT" if randf() <= 0.5 else "RIGHT"
	var atk_type : StringName = PieRand.Roll(chances_for_attack)
	
	navigator.x = left_tunnel_global_pos if choose_side == "LEFT" else right_tunnel_global_pos
	if choose_side == "LEFT":
		if atk_type == "MINIGUN":
			bullets_to_fire = num_bullets_mingun_shoot
			face_left()
		else:
			face_right()
	elif choose_side == "RIGHT":
		if atk_type == "MINIGUN":
			bullets_to_fire = num_bullets_mingun_shoot
			face_right()
		else:
			face_left()
	
	behavior = (state.PERFORM_ATTACK_CHARGE if atk_type == "CHARGE" else 
				state.PERFORM_ATTACK_CHARGE_GUN if atk_type == "CHARGE_LASER" else 
				state.PERFORM_ATTACK_MINIGUN
			)
	
	if atk_type != "MINIGUN":
		if choose_side == "LEFT":
			destination_tunnel = "RIGHT"
		else:
			destination_tunnel = "LEFT"
	
	animator.play("fade_in")

func _on_attack_charge(use_big_gun: bool) -> void:
	if animator.is_playing(): return
	navigator.ignore_target = false
	is_in_background = false
	
	if use_big_gun:
		do_random_big_laser_shot = true
		big_gun.turn_on_gun()
	
	bumper.flash()
	behavior = state.NAV_TUNNEL
	await get_tree().create_timer(randf_range(min_laser_time, max_laser_time)).timeout
	big_gun.turn_off_gun()

func _on_attack_mini_gun() -> void:
	if animator.is_playing(): return
	is_in_background = false
	
	if bullets_to_fire <= 0:
		# The Shoot animation spawns its bullet partway through, so leaving the
		# moment the last shot starts would fire it from halfway down the room.
		if mini_gun.is_shooting():
			return
		enter_tunnel("closest")
		return
	
	# shoot() refuses while the previous shot is still playing. Counting the
	# refusals as shots burned all five rounds in five frames and sent the drone
	# straight back to a tunnel after a single bullet.
	if mini_gun.shoot():
		bullets_to_fire -= 1
#endregion

func set_navigator_speeds(mode: StringName = "DEFAULT") -> void:
	if mode == "YELP":
		navigator.max_speed = max_speed_when_escaping
		navigator.steering_max_force = -1
	elif mode == "DEFAULT":
		navigator.max_speed = max_speed_when_charging
		navigator.steering_max_force = navigator_force_maximum_when_charging

#TODO implement more cleanly
func face_right() -> void:
	scale.x = -3
	mini_gun.is_flipped = true

#TODO implement more cleanly
func face_left() -> void:
	scale.x = 3
	mini_gun.is_flipped = false

func _ready() -> void:
	if GameManager.is_object_collected("Gun"):
		queue_free()
		return
	
	is_dead = false
	_last_wheel_pos = global_position
	# Keep bullets out of the drone's FaderNode so they do not fade and teleport
	# along with it when it ducks into a tunnel.
	mini_gun.bullet_parent = get_parent()
	prefightNodes.attach_collider(intro_collider)
	
	if left_tunnel_pos != null:
		left_tunnel_pos.global_position.y = global_position.y
		left_tunnel_global_pos = left_tunnel_pos.global_position.x
	if right_tunnel_pos != null:
		right_tunnel_pos.global_position.y = global_position.y
		right_tunnel_global_pos = right_tunnel_pos.global_position.x
	
	MusicManager.override_automatic_assignment( true )
	MusicManager.set_background_track_from_name("BOSS", "Ambiance")
	
	health_component.on_destroy_event.connect(flash_and_spawn_gun)
	health_component.on_death_event.connect(on_death)
	health_component.on_hit_event.connect(yelp_in_agony)
	health_component.on_low_health_entry.connect(_swap_charge_chances)
	
	pause_sprite_animations = true

func _swap_charge_chances() -> void:
	print("Swapping to more deadly version")
	chances_for_attack = {
	"CHARGE_LASER": 0.69,
	"MINIGUN": 0.30,
	"CHARGE": 0.01,
}

func on_death() -> void:
	big_gun.turn_on_barrel()
	mini_gun.despawn_bullets()
	navigator.sudden_stop()
	is_dead = true
	exploder.start_explosions()
	MusicManager.try_mute_volume(name)
	motor.stop()
	motor.volume_db = -80
	vocalizer.stop()
	vocalizer.volume_db = -80
	hitbox.queue_free()

func yelp_in_agony() -> void:
	set_navigator_speeds("YELP")
	vocalizer.stream = yelp
	vocalizer.play()
	visuals.flash()
	if health_component.current_health() > 23:
		pass
	elif health_component.current_health() > 18:
		sprite_sheet_swapper.set_sprite_level(1)
	elif health_component.current_health() > 13:
		sprite_sheet_swapper.set_sprite_level(2)
	elif health_component.current_health() > 7:
		sprite_sheet_swapper.set_sprite_level(3)
	if do_intro_cutscene:
		start_intro_cutscene()

func enter_tunnel(querry_mode: StringName) -> void:
	animator.play("accelerate")
	behavior = state.NAV_TUNNEL
	# The minigun attack parks the navigator to hold position while it fires;
	# without this the drone would sit still forever instead of driving off.
	navigator.ignore_target = false
	
	if querry_mode == "left":
		destination_tunnel = "LEFT"
	elif querry_mode == "right":
		destination_tunnel = "RIGHT"
	elif querry_mode == "closest":
		# These have to be compared as distances. Raw deltas made the left tunnel
		# win every time, since its delta is negative whenever the drone is to the
		# right of it -- so a minigun volley on the left re-entered the tunnel it
		# was already sitting in, over and over.
		if absf(left_tunnel_global_pos - global_position.x) < absf(right_tunnel_global_pos - global_position.x):
			destination_tunnel = "LEFT"
		else:
			destination_tunnel = "RIGHT"

func exit_a_tunnel() -> void:
	is_in_background = false

func start_intro_cutscene() -> void:
	if not do_intro_cutscene:
		return
	
	health_component.ignore_effects = true
	enter_tunnel("closest")
	
	# Temp timer to get around lack of intro cutscene
	await get_tree().create_timer(1.0).timeout
	leave_intro_cutscene()

func leave_intro_cutscene() -> void:
	do_intro_cutscene = false
	health_component.ignore_effects = false
	prefightNodes.rawr()
	CameraEffects.shake(17, 1.4, CameraEffects.Axis.BOTH, CameraEffects.Ease.EASE_IN_OUT)
	await prefightNodes.audioStream.finished
	MusicManager.set_background_track_from_name("BOSS", "Containment Drone")

func remove_visuals() -> void:
	if is_instance_valid($FaderNode):
		$FaderNode.queue_free()
	elif is_instance_valid(visuals):
		visuals.queue_free()

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
