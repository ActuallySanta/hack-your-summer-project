class_name Player
extends CharacterBody2D

@export_group("Movement")
@export var moveSpeed := 500.0
@export var jumpForce := 600.0
@export var jumpBufferTime := 0.25
@export var coyoteTime := 0.2
@export_group("Combat")
@export var attackCooldown := 0.45
@export var attackBufferTime := 0.15
@export var swingOffset := 100.0
@export var swingScene : PackedScene

var _moveInput : float
var _facingRight : bool
var _jumpBufferTimer : float
var _coyoteTimer : float
var _attackCooldownTimer : float
var _attackBufferTimer : float

func _ready() -> void:
	PlayerManager.player = self
	_facingRight = true

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

func _physics_process(delta: float) -> void:
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

	# Get the input direction and handle the movement/deceleration.
	if _moveInput:
		velocity.x = _moveInput * moveSpeed
		_facingRight = _moveInput > 0
	else:
		velocity.x = move_toward(velocity.x, 0, moveSpeed)
		
	# Handle attack
	if _attackCooldownTimer > 0:
		_attackCooldownTimer -= delta
	if _attackBufferTimer > 0:
		if _attackCooldownTimer <= 0:
			attack()
		else:
			_attackBufferTimer -= delta

	move_and_slide()

func set_jump_input() -> void:
	_jumpBufferTimer = jumpBufferTime

func set_attack_input() -> void:
	_attackBufferTimer = attackBufferTime

func handle_inputs() -> void:
	_moveInput = Input.get_axis("Left", "Right")
	if Input.is_action_just_pressed("Jump"):
		set_jump_input()
	if Input.is_action_just_pressed("Attack"):
		set_attack_input()

func _process(delta: float) -> void:
	handle_inputs()
	#animation code would go here eventually
