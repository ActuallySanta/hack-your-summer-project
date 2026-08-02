extends BTAction

enum AttackType{
	basicAttack,
	cornerAttack,
	randomAttack
}

@export var currAttackType : AttackType = AttackType.basicAttack
@export var eyeProjectile : PackedScene = preload("uid://1edv7orydrhs")
@export var projectileSpeed : float = 350.0
@export var attackCooldown : float = 150
@export var attackCooldownAggroMult : float = 1.25

func _tick(delta: float) -> Status:
	var user: BossEnemy = agent as BossEnemy
	
	match currAttackType:
		AttackType.basicAttack:
			print("SPAWNED BULLET")
			var instance : BossBullet = eyeProjectile.instantiate()
			instance.global_position = user.attack_point.global_position
			agent.add_child(instance)
			instance.reparent(agent.get_tree().current_scene)
			instance.linear_velocity = instance.global_position.direction_to(PlayerManager.player.global_position)*projectileSpeed
			return Status.SUCCESS
		AttackType.randomAttack:
			for i in 4:
				var instance : BossBullet = eyeProjectile.instantiate()
				var randPos : Vector2 = Vector2(
					randf_range(user.eyeSpawnArea.position.x,user.eyeSpawnArea.size.x),
					randf_range(user.eyeSpawnArea.position.y,user.eyeSpawnArea.size.y))
				instance.position = randPos
				agent.add_child(instance)
				instance.reparent(agent.get_tree().current_scene)
				instance.linear_velocity = instance.global_position.direction_to(PlayerManager.player.global_position)*projectileSpeed
			return Status.SUCCESS
		AttackType.cornerAttack:
			var TRCornerInstance : BossBullet = eyeProjectile.instantiate()
			var TLCornerInstance : BossBullet = eyeProjectile.instantiate()
			var BRCornerInstance : BossBullet = eyeProjectile.instantiate()
			var BLCornerInstance : BossBullet = eyeProjectile.instantiate()
			
			TLCornerInstance.global_position = Vector2(user.eyeSpawnArea.position.x,user.eyeSpawnArea.position.y)
			TRCornerInstance.global_position = Vector2(user.eyeSpawnArea.size.x,user.eyeSpawnArea.position.y)
			BLCornerInstance.global_position = Vector2(user.eyeSpawnArea.position.x,user.eyeSpawnArea.size.y)
			BRCornerInstance.global_position = Vector2(user.eyeSpawnArea.size.x,user.eyeSpawnArea.size.y)
			
			var instances : Array[BossBullet] = [TLCornerInstance,BRCornerInstance,BLCornerInstance,TRCornerInstance]
			
			for i in instances.size():
				instances[i].reparent(agent.get_tree().current_scene)
				instances[i].linear_velocity = instances[i].global_position.direction_to(user.eyeSpawnArea.get_center())*projectileSpeed
			return Status.SUCCESS
		_:
			print("No Attack Type Selected")
			return Status.FAILURE
