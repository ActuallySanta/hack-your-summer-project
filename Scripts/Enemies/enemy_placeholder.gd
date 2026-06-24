extends CharacterBody2D

@export_group("Movement")
@export var speed := 100.0
@export var moving := true
@export var facing_left := false
@export_group("Combat")
@export var base_health := 5
@export var stun_time := 4.0
@export var disable_stuns := false

var _current_knockback_strength : float
var _knockback_timer : float
var _current_health : int
var _stun_timer : float

func _ready() -> void:
	_current_health = base_health

func _physics_process(delta: float) -> void:
	if disable_stuns:
		_stun_timer = 0
		_current_health = base_health
		
	if _knockback_timer > 0:
		knockback_movement(delta)
	elif _stun_timer <= 0 and !disable_stuns:
		standard_movement(delta)
	
	if _stun_timer > 0 or _current_health <= 0:
		_stun_timer -= delta
		if _stun_timer <= 0:
			_current_health = base_health
	
	move_and_slide()

func standard_movement(_delta: float) -> void:
	if moving:
		if facing_left:
			velocity.x = -speed
		else:
			velocity.x = speed
	else:
		velocity.x = 0
	
func knockback_movement(delta: float) -> void:
	velocity.x = _current_knockback_strength
	_knockback_timer -= delta

func _when_hit(_hurtbox: Hurtbox, hit_info: HitInfo, _source: Hitbox) -> void:
	_current_health -= hit_info.damage
	_current_knockback_strength = hit_info.knockback_strength
	_knockback_timer = hit_info.knockback_duration
	if _current_health <= 0:
		_stun_timer = stun_time
