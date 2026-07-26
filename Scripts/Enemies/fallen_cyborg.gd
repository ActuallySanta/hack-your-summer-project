extends Enemy

@export var bullet_spawn_offset : Vector2
@export var start_flipped : bool = false:
	set(value):
		start_flipped = value

@onready var bulletScene = preload("uid://dmxbgtwmp5c0q")
var is_weapon_raised : bool = false

func _ready() -> void:
	bt_player.blackboard.set_var("canAttack",true)
	hurtbox.hit.connect(takeDamage)
	if start_flipped:
		bullet_spawn_offset.x *= -1
		update_flip(-1)

func _physics_process(_delta: float) -> void:
	if bt_player.blackboard.get_var("state") == "hurt":
		return
	
	switch_state("idle")
	
	if shapeCast_hit_playerRef(target_range_check):
		switch_state("attack" if is_weapon_raised else "bear arms")

func spawnBullet():
	velocity = Vector2.ZERO
	bt_player.blackboard.set_var("canAttack",false)
	var instance = bulletScene.instantiate()
	
	instance.initDir = transform.x
	instance.spawnPos = global_position + bullet_spawn_offset
	instance.spawnRot = rotation
	if start_flipped:
		instance.flip_graphics()
	
	mainScene.add_child.call_deferred(instance)
	await get_tree().create_timer(attackCooldown).timeout
	bt_player.blackboard.set_var("canAttack",true)

func set_weapon_raised(val: bool) -> void:
	is_weapon_raised = val
