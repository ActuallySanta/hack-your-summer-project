#@tool

extends Node2D
class_name BossEnemy
@export var maxHealth : float = 150
@onready var currHealth : float = maxHealth

@export var aggroLevel : int = 1
@export var lowerEnvAttackChance : float = 50.0
@export var envAttackWarningDuration : float = 0.5

@onready var environmental_attack_cooldown_timer: Timer = $"Enviromental Attack Cooldown Timer"
@onready var enviromental_attack_duration_timer: Timer = $"Enviromental Attack Duration Timer"

@onready var upper_environmental_attack_warning: Sprite2D = $"Upper Environmental Attack Warning"
@onready var lower_environmental_attack_warning: Sprite2D = $"Lower Environmental Attack Warning"

@onready var lower_teeth_attack: TileMapLayer = $"Lower Teeth Attack"
@onready var upper_teeth_attack: TileMapLayer = $"Upper Teeth Attack"

@onready var hurtbox: Hurtbox = $BossVisual/Hurtbox
@onready var attack_point: Node2D = $BossVisual/Hurtbox/AttackPoint
@onready var health_bar: ProgressBar = $"CanvasLayer/Health Bar"

@onready var hurt_sfx: AudioStreamPlayer = $SFX/HurtSFX

@export var eyeSpawnArea : Rect2:
	set(value):
		eyeSpawnArea = value
		queue_redraw()

var minEyeCount := 3

@export var minEnvironmentalAttackCooldown :float = 5.0
var envAttackDuration : float = 2.5
var envAttackAggressionModifiers : Array = [1.0,.75,.5]

func _ready() -> void:
	health_bar.max_value = maxHealth
	health_bar.value = currHealth
	lower_teeth_attack.reparent(get_tree().current_scene)
	upper_teeth_attack.reparent(get_tree().current_scene)
	
	lower_environmental_attack_warning.reparent(get_tree().current_scene)
	upper_environmental_attack_warning.reparent(get_tree().current_scene)
	
	upper_environmental_attack_warning.visible = false
	lower_environmental_attack_warning.visible = false
	
	disableEnvAttacks()
	environmental_attack_cooldown_timer.wait_time = minEnvironmentalAttackCooldown
	environmental_attack_cooldown_timer.start()
	await environmental_attack_cooldown_timer.timeout
	_environmentalAttack()


func _environmentalAttack():
	enviromental_attack_duration_timer.wait_time = envAttackDuration * envAttackAggressionModifiers[aggroLevel]
	
	var attackChoice : float = randf_range(0,1)
	if(attackChoice < (lowerEnvAttackChance/100.0)):
		lower_environmental_attack_warning.visible = true
		await get_tree().create_timer(envAttackWarningDuration).timeout
		lower_environmental_attack_warning.visible = false
		
		#Do the lower teeth attack
		lower_teeth_attack.visible = true
		lower_teeth_attack.process_mode = Node.PROCESS_MODE_INHERIT
		pass
	else:
		upper_environmental_attack_warning.visible = true
		await get_tree().create_timer(envAttackWarningDuration).timeout
		upper_environmental_attack_warning.visible = false
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


func _draw() -> void:
	draw_rect(eyeSpawnArea,Color(0.024, 0.502, 1.0, 1.0),20, true)


func _on_hurtbox_hit(hurtBox: Hurtbox, hit_info: HitInfo, source: Hitbox) -> void:
	currHealth -= hit_info.damage
	hurt_sfx.play()
	health_bar.value = currHealth
	if(currHealth > (maxHealth *(1/3)) and currHealth < (maxHealth*(2/3))):
		#Phase 2
		aggroLevel = 2
	elif(currHealth > 0 and currHealth < (maxHealth*(1/3))):
		#Phase 3
		aggroLevel = 3
	elif(currHealth <= 0):
		#Boss Die
		GlobalSignals.OnBossDie.emit()
		queue_free()
	
	pass
