extends Enemy

@onready var bulletScene = preload("uid://dmxbgtwmp5c0q")

func _physics_process(_delta: float) -> void:
	if bt_player.blackboard.get_var("state") == "hurt":
		return
	
	switch_state("idle")
	
	if not player_detection_check.collision_result.find(playerReference):
		return
	
	switch_state(
		"patrolling" if not can_see_player() 
		else "attacking" if target_range_check.collision_result.find(playerReference)
		else "chasing"
	)

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
