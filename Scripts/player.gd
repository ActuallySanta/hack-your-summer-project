class_name Player
extends CharacterBody2D

@export_group("Movement")
@export var moveSpeed := 500.0
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

@onready var sprite : AnimatedSprite2D = $AnimatedSprite2D

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
		velocity += get_gravity() * delta
		_coyoteTimer -= delta
	else:
		_coyoteTimer = coyoteTime
	# Handle jump.
	if _jumpBufferTimer > 0:
		if is_on_floor() or _coyoteTimer > 0:
			jump()
		else:
			_jumpBufferTimer -= delta
	

func handle_standard_movement(_delta: float) -> void:
	# Get the input direction and handle the movement/deceleration.
	if _moveInput:
		velocity.x = _moveInput * moveSpeed
		_facingRight = _moveInput > 0
	else:
		velocity.x = move_toward(velocity.x, 0, moveSpeed)

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

func set_jump_input() -> void:
	_jumpBufferTimer = jumpBufferTime

func set_attack_input() -> void:
	_attackBufferTimer = attackBufferTime

func set_shoot_input() -> void:
	_shootBufferTimer = shootBufferTime

func handle_inputs() -> void:
	_moveInput = Input.get_axis("Left", "Right")
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

func _process(delta: float) -> void:
	handle_inputs()
	handle_invuln_blinking(delta)
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
