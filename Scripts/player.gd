class_name Player
extends CharacterBody2D

signal pickup_collected(pickup : Pickup)
signal save_station_used()

## Get animationtree ##
@onready var animator: AnimationTree = $AnimationTree
@onready var animPlayback: AnimationNodeStateMachinePlayback = animator.get("parameters/playback")

const IDLESTATEPARAM := "parameters/StandardMovement/Idle/MoveState/transition_request"
const MOVESTATEPARAM := "parameters/StandardMovement/Move/MoveState/transition_request"
const FIRESTATEPARAM := "parameters/RangedFire/MoveState/transition_request"

@export_group("Movement")
@export var moveSpeed := 500.0
@export var crouchSpeedMult := 0.5
@export var climbingSpeed := 100
@export var jumpForce := 600.0
@export var jumpBufferTime := 0.25
@export var coyoteTime := 0.2

@export_group("Combat")
@export var baseHealth := 5
@export var attackCooldown := 0.45
@export var attackBufferTime := 0.15
@export var swingOffset := 100.0
@export var swingScene : PackedScene
@export var shootCooldown := 0.6
@export var shootBufferTime := 0.15
@export var bulletOffset := 100.0
@export var bulletScene : PackedScene
@export var hitInvulnTime := 1.0
@export var invulnBlinkInterval := 0.15
@export var knockbackDI := 300.0
@export var deathRespawnDelay := 2.0

var _moveInput : float
var _vertMoveInput :float
var _crouchInput : bool
var _climbInput : bool
var _facingRight : bool
var _jumpBufferTimer : float
var _coyoteTimer : float
var _currentHealth : int
var _attackCooldownTimer : float
var _attackBufferTimer : float
var _shootCooldownTimer : float
var _shootBufferTimer : float
var _knockbackTimer : float
var _knockbackForce : float
var _invulnTimer : float
var _invulnBlinkTimer : float
var _deathRespawnTimer : float

enum MoveState{
	Standing,
	Crouching,
	Climbing,
	Jumping,
	Knockback
}

var playerMoveState: MoveState

var anim_moving : bool
var anim_jumping : bool
var anim_hurt : bool
var anim_death : bool
var anim_swing : bool
var anim_fire : bool

@onready var jetpack: Sprite2D = $JetpackAsset
@onready var sprite : Sprite2D = $Character

func _ready() -> void:
	PlayerManager.player = self
	_facingRight = true
	_currentHealth = baseHealth
	CheckpointEventBus.move_player_position.connect(_move_player_pos)
	jetpack.jetpack_updated.connect(do_jetpack_logic)
	disable_jetpack()

func _move_player_pos(pos: Vector2) -> void:
	position = pos


func jump() -> void:
	velocity.y = -jumpForce
	_jumpBufferTimer = 0
	_coyoteTimer = 0


func attack() -> void:
	print("Attack!")
	var newAttack := swingScene.instantiate() as PlayerMeleeSwing
	var swingX := swingOffset
	if !_facingRight:
		swingX *= -1
		newAttack.scale.x = -1
	newAttack.position = Vector2(swingX, 0)
	add_child(newAttack)
	_attackCooldownTimer = attackCooldown
	_shootCooldownTimer = attackCooldown
	_attackBufferTimer = 0
	anim_swing = true


func shoot() -> void:
	print("Fire!")
	var newBullet := bulletScene.instantiate() as PlayerBullet
	var bulletX := bulletOffset
	if !_facingRight:
		bulletX *= -1
		newBullet.scale.x = -1
	newBullet.position = position + Vector2(bulletX, 0)
	newBullet.direction = Vector2.RIGHT if _facingRight else Vector2.LEFT
	get_tree().root.add_child(newBullet)
	_shootCooldownTimer = shootCooldown
	_attackCooldownTimer = shootCooldown
	_shootBufferTimer = 0
	anim_fire = true


func handle_jump_and_gravity(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		if(playerMoveState != MoveState.Climbing):
			velocity += get_gravity() * delta
		_coyoteTimer -= delta
	else:
		_coyoteTimer = coyoteTime
	
	# Handle jump.
	if _jumpBufferTimer > 0:
		if (is_on_floor() or _coyoteTimer > 0) and playerMoveState != MoveState.Climbing:
			jump()
		else:
			_jumpBufferTimer -= delta


func handle_standard_movement(_delta: float) -> void:
	# Get the input direction and handle the movement/deceleration.
	if _moveInput:
		velocity.x = _moveInput * moveSpeed
		if(playerMoveState == MoveState.Crouching):
			velocity.x *= crouchSpeedMult
		_facingRight = _moveInput > 0
	else:
		velocity.x = move_toward(velocity.x, 0, moveSpeed)
	set_anim_move_state(playerMoveState, _moveInput != 0)


func handle_climbing_movement(_delta: float) -> void:
	velocity.x = 0
	velocity.y = _vertMoveInput * climbingSpeed
	set_anim_move_state(MoveState.Climbing, _vertMoveInput != 0)


func handle_knockback_movement(delta: float) -> void:
	velocity.x = _knockbackForce
	if _moveInput:
		velocity.x += _moveInput * knockbackDI
	_knockbackTimer -= delta
	set_anim_move_state(MoveState.Knockback, false)


func determine_move_state() -> MoveState:
	if _knockbackTimer > 0:
		return MoveState.Knockback
	
	if is_on_wall() and _climbInput:
		return MoveState.Climbing
	
	if !is_on_floor():
		return MoveState.Jumping
	
	if _crouchInput:
		return MoveState.Crouching
	
	return MoveState.Standing


func set_anim_move_state(moveState: MoveState, moving: bool) -> void:
	match moveState:
		MoveState.Standing:
			animator.set(IDLESTATEPARAM, "Stand")
			animator.set(MOVESTATEPARAM, "Stand")
			animator.set(FIRESTATEPARAM, "Stand")
			anim_jumping = false
			anim_moving = moving
			anim_hurt = false
		MoveState.Crouching:
			animator.set(IDLESTATEPARAM, "Crouch")
			animator.set(MOVESTATEPARAM, "Crouch")
			animator.set(FIRESTATEPARAM, "Crouch")
			anim_jumping = false
			anim_moving = moving
			anim_hurt = false
		MoveState.Climbing:
			animator.set(IDLESTATEPARAM, "Climb")
			animator.set(MOVESTATEPARAM, "Climb")
			animator.set(FIRESTATEPARAM, "Jump")
			anim_jumping = false
			anim_moving = moving
			anim_hurt = false
		MoveState.Jumping:
			animator.set(FIRESTATEPARAM, "Jump")
			anim_jumping = true
			anim_moving = true
			anim_hurt = false
		MoveState.Knockback:
			anim_hurt = true


func _physics_process(delta: float) -> void:
	playerMoveState = determine_move_state()
	
	handle_jump_and_gravity(delta)
	
	if playerMoveState == MoveState.Knockback:
		handle_knockback_movement(delta)
	elif playerMoveState == MoveState.Climbing:
		handle_climbing_movement(delta)
	else:
		handle_standard_movement(delta)
	# Handle attack
	if _attackCooldownTimer > 0:
		_attackCooldownTimer -= delta
	if _attackBufferTimer > 0:
		if _attackCooldownTimer <= 0:
			attack()
		else:
			_attackBufferTimer -= delta
	# Handle shooting
	if _shootCooldownTimer > 0:
		_shootCooldownTimer -= delta
	if _shootBufferTimer > 0:
		if _shootCooldownTimer <= 0:
			shoot()
		else:
			_shootBufferTimer -= delta
	
	if _invulnTimer > 0:
		_invulnTimer -= delta
	move_and_slide()

	# 3. Flip the sprite visually based on which way we are running
	if _moveInput > 0:
		$Character.flip_h = false  # Facing Right
	elif _moveInput < 0:
		$Character.flip_h = true   # Facing Left

func set_jump_input() -> void:
	_jumpBufferTimer = jumpBufferTime
	
func unset_jump_input() -> void:
	_jumpBufferTimer = 0

func set_attack_input() -> void:
	_attackBufferTimer = attackBufferTime
	
func unset_attack_input() -> void:
	_attackBufferTimer = 0

func set_shoot_input() -> void:
	_shootBufferTimer = shootBufferTime
	
func unset_shoot_input() -> void:
	_shootBufferTimer = 0

func reset_all_inputs() -> void:
	_moveInput = 0
	_vertMoveInput = 0
	_crouchInput = 0
	_climbInput = 0
	unset_jump_input()
	unset_attack_input()
	unset_shoot_input()

func handle_inputs() -> void:
	if(!PlayerManager.canMove or _currentHealth <= 0): return
	
	_moveInput = Input.get_axis("Left", "Right")
	_vertMoveInput = Input.get_axis("Up","Down")
	_crouchInput = Input.is_action_pressed("Crouch")
	_climbInput = Input.is_action_pressed("Climb")	
	
	if Input.is_action_just_pressed("Jump"):
		set_jump_input()
	if Input.is_action_just_pressed("Attack"):
		set_attack_input()
	if Input.is_action_just_pressed("Shoot"):
		set_shoot_input()

func handle_invuln_blinking(delta: float) -> void:
	if _invulnTimer <= 0:
		_invulnBlinkTimer = 0
		sprite.show()
		return
	
	if _invulnBlinkTimer > invulnBlinkInterval/2:
		sprite.hide()
	else:
		sprite.show()
	_invulnBlinkTimer -= delta
	if _invulnBlinkTimer < 0:
		_invulnBlinkTimer += invulnBlinkInterval

func _process( _delta: float) -> void:
	handle_inputs()
	handle_invuln_blinking(_delta)
	
	if _deathRespawnTimer > 0:
		_deathRespawnTimer -= _delta
		if _deathRespawnTimer <= 0:
			respawn()
	if animPlayback.get_current_node() == "RangedFire" or animPlayback.get_current_node() == "MeleeSwing":
		anim_fire = false
		anim_swing = false

func die() -> void:
	_invulnTimer = 0
	anim_death = true
	_deathRespawnTimer = deathRespawnDelay
	reset_all_inputs()
	_moveInput = 0

func respawn() -> void:
	_currentHealth = baseHealth
	GlobalSignals.health_changed.emit(_currentHealth, baseHealth)
	_deathRespawnTimer = 0
	anim_death = false
	CheckpointEventBus.player_needs_to_use_checkpoint.emit()

func _on_hit(_hurtBox: Hurtbox, hit_info: HitInfo, _source: Hitbox) -> void:
	if _invulnTimer > 0:
		return
	print("Player took damage!")
	_currentHealth -= hit_info.damage
	GlobalSignals.health_changed.emit(_currentHealth, baseHealth)
	_knockbackTimer = hit_info.knockback_duration
	_knockbackForce = hit_info.knockback_strength / _knockbackTimer
	_invulnTimer = hitInvulnTime
	_invulnBlinkTimer = invulnBlinkInterval
	anim_hurt = true
	if _currentHealth <= 0:
		die()

func collect(pickup: Pickup) -> bool:
	print("Collect pickup " + pickup.get_type_as_str())
	pickup_collected.emit(pickup)
	return true

func do_jetpack_logic(speed: float):
	velocity.y -= speed;

func disable_jetpack() -> void:
	jetpack.process_mode = Node.PROCESS_MODE_DISABLED

func enable_jetpack() -> void:
	jetpack.process_mode = Node.PROCESS_MODE_INHERIT
