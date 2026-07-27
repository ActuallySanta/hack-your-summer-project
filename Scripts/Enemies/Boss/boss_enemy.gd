extends Enemy

@export var aggroLevel : int = 1
@export var lowerEnvAttackChance : float = 50.0

@onready var enviromental_attack_timer: Timer = $"Enviromental Attack Timer"



var minEyeCount := 3

var minEnvironmentalAttackCooldown :float = 10.0
var envAttackCooldowns : Array = [1.0,.75,.5]

func _ready() -> void:
	enviromental_attack_timer.wait_time = minEnvironmentalAttackCooldown
	_environmentalAttack()

func _spawnEyes():
	pass

func _environmentalAttack():
	await enviromental_attack_timer.timeout
	var attackChoice : float = randf_range(0,1)
	if(attackChoice < (lowerEnvAttackChance/100.0)):
		#Do the lower teeth attack
		pass
	else:
		#Do the upper tentacle attack
		pass
	#Make the environmental attack levels faster as the aggression levels increase
	enviromental_attack_timer.wait_time = minEnvironmentalAttackCooldown * envAttackCooldowns[aggroLevel]
