extends Enemy
@export var fire_check_timer : float = 0.4
@export var bullet_spawn_offset : Vector2
@export var start_flipped : bool = false:
	set(value):
		start_flipped = value

@export var bulletScene := preload("uid://dx27csn4jx8c3")

@onready var animator := $AnimationPlayer

var is_weapon_raised : bool = false
var timer := 0.0

func _ready() -> void:
	bt_player.blackboard.set_var("canAttack",true)
	hurtbox.hit.connect(takeDamage)
	if start_flipped:
		bullet_spawn_offset.x *= -1
		update_flip(-1)
	switch_state("idle")

func _physics_process(delta: float) -> void:
	timer = max(0, timer - delta)
	if bt_player.blackboard.get_var("state") == "hurt":
		return

	if shapeCast_hit_playerRef(target_range_check):
		timer = fire_check_timer
	
	if timer > 0:
		switch_state("attack" if is_weapon_raised else "bear arms")
	elif animator.assigned_animation == "attack":
		switch_state("go rest")
	elif animator.assigned_animation == "bear_arms":
		switch_state("idle")

func spawnBullet():
	velocity = Vector2.ZERO
	bt_player.blackboard.set_var("canAttack",false)
	var instance : Bullet = bulletScene.instantiate()
	instance.initial_operations(global_position + bullet_spawn_offset, "L" if start_flipped else "R", 0)
	instance.scale = Vector2(3,3)
	mainScene.add_child.call_deferred(instance)
	await get_tree().create_timer(attackCooldown).timeout
	bt_player.blackboard.set_var("canAttack",true)

func set_weapon_raised(val: bool) -> void:
	is_weapon_raised = val
	
