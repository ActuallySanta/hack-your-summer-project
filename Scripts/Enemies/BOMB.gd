extends Node2D

const EXPLOSION := preload("res://Scenes/Enemies/enemy_death_boom.tscn")
@export var explosion_time : float = 0.1
@export var explosion_brightness : float = 10.0

@onready var manin_flash : Node2D = $RigidBody2D/Flash

var _timer = -1
var boomed = false
var going_for_delete = false

func _ready() -> void:
	manin_flash.modulate.a = 0

func _process(delta: float) -> void:
	if boomed:
		return
	if _timer < 0: return
	if _timer >= explosion_time:
		_KABOOM()
		return
	
	_timer += delta
	var color = explosion_brightness * _timer / explosion_time
	modulate = Color(color,color,color)
	manin_flash.modulate.a = _timer * _timer / explosion_time

func _physics_process(_delta: float) -> void:
	if $RigidBody2D != null:
		$PlayerCollider.position = $RigidBody2D.position
	elif $PlayerCollider != null:
		$PlayerCollider.queue_free()
	
	if boomed and not going_for_delete:
		going_for_delete = true
		await get_tree().physics_frame
		queue_free()
	
func _BOOM_BOOM_BOOM() -> void:
	if _timer >= 0: return
	_timer = 0

func _KABOOM() -> void:
	$Hitbox.monitorable  = true
	$Hitbox.monitoring  = true
	var effects : Node2D = EXPLOSION.instantiate()
	effects.global_position = $RigidBody2D.global_position
	$Hitbox.global_position = effects.global_position
	get_tree().root.add_child(effects)
	$RigidBody2D.queue_free()
	boomed = true

func _on_player_collider_body_entered(body: Node2D) -> void:
	_BOOM_BOOM_BOOM()

func _on_hurtbox_hit(_hurtbox: Hurtbox, _hit_info: HitInfo, _source: Hitbox) -> void:
	_BOOM_BOOM_BOOM()
