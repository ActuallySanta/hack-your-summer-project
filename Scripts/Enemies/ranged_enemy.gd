extends Enemy

@onready var bulletScene = preload("uid://dmxbgtwmp5c0q")







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
