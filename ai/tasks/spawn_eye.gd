extends BTAction

enum AttackType{
	basicAttack,
	shotgunAttack,
	cornerAttack
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
		_:
			print("No Attack Type Selected")
			return Status.FAILURE
