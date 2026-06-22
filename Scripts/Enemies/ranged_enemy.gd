extends Enemy

@onready var bulletScene = preload("res://Scenes/ranged_enemy_bullet.tscn")


var isFlipped : bool

func _ready() -> void:
	bt_player.blackboard.set_var("canAttack",true)

func move(targetPos : Vector2, delta :float):
	var dir : Vector2 = Vector2(targetPos.x - global_position.x,0).normalized()
	
	velocity.x = dir.x * SPEED
	update_flip(dir.x)

func update_flip(dir:float):
	var doFlip : bool = dir<0
	if(doFlip != isFlipped):
		scale.x =-1
	else:
		scale.x = 1
	isFlipped = doFlip

func spawnBullet():
	velocity = Vector2.ZERO
	bt_player.blackboard.set_var("canAttack",false)
	var instance = bulletScene.instantiate()
	instance.initDir = transform.x
	instance.spawnPos = global_position
	instance.spawnRot = rotation
	mainScene.add_child.call_deferred(instance)
	
	await get_tree().create_timer(attackCooldown).timeout
	
	bt_player.blackboard.set_var("canAttack",true)
	pass
