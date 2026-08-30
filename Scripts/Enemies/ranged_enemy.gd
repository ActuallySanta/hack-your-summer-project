extends Enemy

@onready var bulletScene = preload("uid://dmxbgtwmp5c0q")
@onready var firing_point: Node2D = $FiringPoint

func spawnBullet():
	velocity = Vector2.ZERO
	bt_player.blackboard.set_var("canAttack",false)
	var instance : Bullet = bulletScene.instantiate()
	instance.initial_operations(firing_point.global_position, get_dir(), 0)
	mainScene.add_child.call_deferred(instance)
	
	await get_tree().create_timer(attackCooldown).timeout
	
	bt_player.blackboard.set_var("canAttack",true)
