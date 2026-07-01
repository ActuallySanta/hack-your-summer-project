class_name Player
extends CharacterBody2D
## Get animationtree ##
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var playback = animation_tree.get("parameters/playback") # Controls the transitions
@export_group("Movement")

@export var moveSpeed := 500.0
@export var crouchSpeedMult := 0.5
@export var climingSpeedMult := 0.75
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

var _moveInput : float
var _vertMoveInput :float
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

enum MoveState{
	Standing,
	Crouching,
	Climbing
}

var playerMoveState: MoveState

@onready var sprite : Sprite2D = $Character
func _ready() -> void:
	PlayerManager.player = self
	_facingRight = true
	_currentHealth = baseHealth
	

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
	newAttack.position = Vector2(swingX, 0)
	add_child(newAttack)
	_attackCooldownTimer = attackCooldown
	_attackBufferTimer = 0

func shoot() -> void:
	print("Fire!")
	var newBullet := bulletScene.instantiate() as PlayerBullet
	var bulletX := bulletOffset
	if !_facingRight:
		bulletX *= -1
	newBullet.position = position + Vector2(bulletX, 0)
	newBullet.direction = Vector2.RIGHT if _facingRight else Vector2.LEFT
	get_tree().root.add_child(newBullet)
	_shootCooldownTimer = shootCooldown
	_shootBufferTimer = 0

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
		if is_on_floor() or _coyoteTimer > 0 and playerMoveState != MoveState.Climbing:
			jump()
		else:
			_jumpBufferTimer -= delta
	

func handle_standard_movement(_delta: float) -> void:
	# Get the input direction and handle the movement/deceleration.
	if _moveInput or _vertMoveInput:
		if(playerMoveState == MoveState.Climbing):
			velocity.y = _vertMoveInput*moveSpeed*climingSpeedMult
		else:
			if(playerMoveState == MoveState.Standing):
				velocity.x = _moveInput * moveSpeed
			else: if(playerMoveState == MoveState.Crouching):
				velocity.x = _moveInput *moveSpeed*crouchSpeedMult
			_facingRight = _moveInput > 0
	else:
		velocity.x = move_toward(velocity.x, 0, moveSpeed)
		if(playerMoveState == MoveState.Climbing):
			velocity.y = move_toward(velocity.y, 0, moveSpeed)

func handle_knockback_movement(delta: float) -> void:
	velocity.x = _knockbackForce
	if _moveInput:
		velocity.x += _moveInput * knockbackDI
	_knockbackTimer -= delta

func _physics_process(delta: float) -> void:
	
	
	handle_jump_and_gravity(delta)
	
	if _knockbackTimer <= 0:
		handle_standard_movement(delta)
	else:
		handle_knockback_movement(delta)
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

	# --- ANIMATION TREE ENGINE LINK ---
	# 1. Check if we are mid-air (jumping or falling)
	if not is_on_floor():
		if(playerMoveState == MoveState.Climbing):
			playback.travel("climb")
		else:
			playback.travel("jump")
	else:
		# 2. If we are grounded, swap between running and idling
		if velocity.x != 0:
			if(playerMoveState == MoveState.Standing):
				playback.travel("run")
			else: if(playerMoveState == MoveState.Crouching):
				playback.travel("crawl")
		else:
			playback.travel("idle")
	# 3. Flip the sprite visually based on which way we are running
	if _moveInput > 0:
		$Character.flip_h = false  # Facing Right
	elif _moveInput < 0:
		$Character.flip_h = true   # Facing Left

func set_jump_input() -> void:
	_jumpBufferTimer = jumpBufferTime

func set_attack_input() -> void:
	_attackBufferTimer = attackBufferTime

func set_shoot_input() -> void:
	_shootBufferTimer = shootBufferTime

func handle_inputs() -> void:
	if(!PlayerManager.canMove): return
	
	_moveInput = Input.get_axis("Left", "Right")
	_vertMoveInput = Input.get_axis("Up","Down")
	if(Input.is_action_pressed("Crouch") and is_on_floor()):
		playerMoveState = MoveState.Crouching
	elif(Input.is_action_pressed("Climb") and !is_on_floor() and is_on_wall()):
		playerMoveState = MoveState.Climbing
	else:
		playerMoveState = MoveState.Standing
	
	
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
	#animation code would go here eventually

func die() -> void:
	print("Player Died! (and revived at full health)")
	_currentHealth = baseHealth

func _on_hit(_hurtBox: Hurtbox, hit_info: HitInfo, _source: Hitbox) -> void:
	if _invulnTimer > 0:
		return
	print("Player took damage!")
	_currentHealth -= hit_info.damage
	_knockbackTimer = hit_info.knockback_duration
	_knockbackForce = hit_info.knockback_strength / _knockbackTimer
	_invulnTimer = hitInvulnTime
	_invulnBlinkTimer = invulnBlinkInterval
	if _currentHealth <= 0:
		die()
