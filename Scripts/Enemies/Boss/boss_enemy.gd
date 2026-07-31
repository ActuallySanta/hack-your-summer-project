extends Node2D
class_name BossEnemy
@export var maxHealth : float = 150
@onready var currHealth : float = maxHealth

@export var aggroLevel : int = 1
@export var lowerEnvAttackChance : float = 50.0

@onready var environmental_attack_cooldown_timer: Timer = $"Enviromental Attack Cooldown Timer"
@onready var enviromental_attack_duration_timer: Timer = $"Enviromental Attack Duration Timer"

@onready var lower_teeth_attack: TileMapLayer = $"Lower Teeth Attack"
@onready var upper_teeth_attack: TileMapLayer = $"Upper Teeth Attack"

@onready var hurtbox: Hurtbox = $BossVisual/Hurtbox
@onready var attack_point: Node2D = $BossVisual/AttackPoint


var minEyeCount := 3

var minEnvironmentalAttackCooldown :float = 10.0
var envAttackDuration : float = 2.5
var envAttackAggressionModifiers : Array = [1.0,.75,.5]

func _ready() -> void:
	hurtbox.hit.connect(_takeDamage)
	
	lower_teeth_attack.reparent(get_tree().current_scene)
	upper_teeth_attack.reparent(get_tree().current_scene)
	disableEnvAttacks()
	environmental_attack_cooldown_timer.wait_time = minEnvironmentalAttackCooldown
	environmental_attack_cooldown_timer.start()
	await environmental_attack_cooldown_timer.timeout
	_environmentalAttack()

func _process(delta: float) -> void:
	
	if(PlayerManager.player != null):
		position.x = lerp(position.x,PlayerManager.player.position.x,0.01)


func _environmentalAttack():
	enviromental_attack_duration_timer.wait_time = envAttackDuration * envAttackAggressionModifiers[aggroLevel]
	
	var attackChoice : float = randf_range(0,1)
	if(attackChoice < (lowerEnvAttackChance/100.0)):
		#Do the lower teeth attack
		lower_teeth_attack.visible = true
		lower_teeth_attack.process_mode = Node.PROCESS_MODE_INHERIT
		pass
	else:
		#Do the upper tentacle attack
		upper_teeth_attack.visible = true
		upper_teeth_attack.process_mode = Node.PROCESS_MODE_INHERIT
		pass
	enviromental_attack_duration_timer.start()
	await enviromental_attack_duration_timer.timeout
	disableEnvAttacks()
	#Make the environmental attack levels faster as the aggression levels increase
	environmental_attack_cooldown_timer.wait_time = minEnvironmentalAttackCooldown * envAttackAggressionModifiers[aggroLevel]
	environmental_attack_cooldown_timer.start()
	await  environmental_attack_cooldown_timer.timeout
	_environmentalAttack()

func disableEnvAttacks():
	upper_teeth_attack.visible = false
	upper_teeth_attack.process_mode = Node.PROCESS_MODE_DISABLED
	
	lower_teeth_attack.visible = false
	lower_teeth_attack.process_mode = Node.PROCESS_MODE_DISABLED

func _takeDamage(_hitInfo : HitInfo):
	currHealth -= _hitInfo.damage
	
	if(currHealth > (maxHealth *(1/3)) and currHealth < (maxHealth*(2/3))):
		#Phase 2
		aggroLevel = 2
	elif(currHealth > 0 and currHealth < (maxHealth*(1/3))):
		#Phase 3
		aggroLevel = 3
	else:
		#Boss Die
		queue_free()
	
	pass
