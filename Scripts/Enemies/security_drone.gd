extends RigidBody2D


const BULLET_SCENE := preload("res://Scenes/Enemies/turret_bullet.tscn")

@export var bullet_spawn_distance := 40.0
@export var do_chaos : bool = false
@export var action_wait_time : float = 1.0

@onready var sprite := $Sprite2D
@onready var audio_player := $AudioStreamPlayer2D
@onready var animator := $AnimationPlayer
@onready var idle_audio : AudioStreamPlayer2D = $IdleAudioPlayer

var timer := 0.0
var state := 0
var is_dead := false

func _process(delta: float) -> void:
	if is_dead:
		return
		
	if not idle_audio.is_playing() and randi() % 200 < 2:
		idle_audio.play()
	
	# decrease the timer
	if timer > 0:
		timer -= delta
		return
	
	if not do_chaos:
		state += 1
		state %= 4
		timer = action_wait_time
	
		match state:
			0: # make straight
				animator.play("Rotate_make_straight")
			1: # attack
				animator.play("Attack_Planar")
			2: # make angular
				animator.play("Rotate_make_angular")
			3: # attack angular
				animator.play("Attack_Angluar")
		return
	
	# handle actual behavior
	match state:
		0: # rest straight
			timer = randf_range(0,0.3)
			state = 1
		1: # decide to attack or wait again
			var decision = randi_range(0,3)
			state = 3 if decision == 0 else 2 if decision == 1 else 0
		2: # attack
			timer = action_wait_time
			state = 1
			animator.play("Attack_Planar")
		3: # rotate to angular
			timer = action_wait_time
			state = 4
			animator.play("Rotate_make_angular")
		4:
			timer = randf_range(0,0.3)
			state = 5
		5: # decide what to do again
			var decision = randi_range(0,3)
			state = 7 if decision == 0 else 6 if decision == 1 else 4
		6: # attack angular
			timer = action_wait_time
			state = 5
			animator.play("Attack_Angluar")
		7: # make planar
			timer = action_wait_time
			state = 0
			animator.play("Rotate_make_straight")

func _shoot(at_angle: bool) -> void:
	var dirs : Array = [ "UR","DR","DL","UL" ] if at_angle else [ "U","R","D","L" ]
	for dir in dirs:
		var bullet = BULLET_SCENE.instantiate() as Bullet
		bullet.initDir = dir
		bullet.spawnPos = position
		bullet.start_offset = bullet_spawn_distance
		bullet.initial_operations()
		get_parent().add_child(bullet)

func _die() -> void:
	var parent = get_parent()
	if parent is Path:
		if parent.remove_node(self):
			print(" I was removed successfully")
		else:
			print(" Something has gone terribly, terribly wrong and I have no idea how to fix this")
	animator.play("Death")
	gravity_scale = 1.0
	is_dead = true
	get_tree().create_timer(5).timeout

func _on_hit(hit_info: HitInfo, source: Hitbox) -> void:
	if hit_info.damage == 0:
		pass
