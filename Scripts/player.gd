class_name Player extends CharacterBody2D

var cardinal_direction : Vector2 = Vector2.DOWN
var direction : Vector2 = Vector2.ZERO

@onready var animation_player : AnimationPlayer = $AnimationPlayer
@onready var state_machine : PlayerStateMachine = $StateMachine

@export var moveSpeed := 500.0
@export var jumpForce := 600.0
@export var jumpBufferTime := 0.25
@export var coyoteTime := 0.2

signal DirectionChanged( new_direction : Vector2 )

var _moveInput : float
var _jumpBufferTimer : float
var _coyoteTimer : float

func _ready() -> void:
	PlayerManager.player = self
	state_machine.Initialize(self)

func jump() -> void:
	velocity.y = -jumpForce
	_jumpBufferTimer = 0
	_coyoteTimer = 0

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
	else:
		velocity.x = move_toward(velocity.x, 0, moveSpeed)

	move_and_slide()

func set_jump_input() -> void:
	_jumpBufferTimer = jumpBufferTime

func handle_inputs() -> void:
	_moveInput = Input.get_axis("ui_left", "ui_right")
	if Input.is_action_just_pressed("ui_accept"):
		set_jump_input()

func _process(delta: float) -> void:
	handle_inputs()
	#animation code would go here eventually

func UpdateAnimation( state : String ) -> void:
	#if state == "RESET":
		#animation_player.play("RESET")  # just play RESET with no direction suffix
	#else:
	animation_player.play(state + "_" + AnimDirection())

func AnimDirection() -> String:
	if cardinal_direction == Vector2.DOWN:
		return "down"
	elif cardinal_direction == Vector2.UP:
		return "up"
	else:
		return "side"
