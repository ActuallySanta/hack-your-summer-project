extends CharacterBody2D
## Get animationtree ##
@onready var anim_tree: AnimationTree = $AnimationTree
@onready var playback = anim_tree.get("parameters/playback") # Controls the transitions

@export var moveSpeed := 250.0
@export var jumpForce := 300.0
@export var jumpBufferTime := 0.25
@export var coyoteTime := 0.2

var _moveInput : float
var _jumpBufferTimer : float
var _coyoteTimer : float

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

	# --- ANIMATION TREE ENGINE LINK ---
	# 1. Check if we are mid-air (jumping or falling)
	if not is_on_floor():
		playback.travel("jump")
	else:
		# 2. If we are grounded, swap between running and idling
		if velocity.x != 0:
			playback.travel("run")
		else:
			playback.travel("idle")
			
	# 3. Flip the sprite visually based on which way we are running
	if _moveInput > 0:
		$Character.flip_h = false  # Facing Right
	elif _moveInput < 0:
		$Character.flip_h = true   # Facing Left

func set_jump_input() -> void:
	_jumpBufferTimer = jumpBufferTime

func handle_inputs() -> void:
	_moveInput = Input.get_axis("ui_left", "ui_right")
	if Input.is_action_just_pressed("ui_accept"):
		set_jump_input()

func _process( _delta: float) -> void:
	handle_inputs()
	#animation code would go here eventually
