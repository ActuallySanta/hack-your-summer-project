extends CharacterBody2D


@export var moveSpeed := 500.0
@export var jumpForce := 600.0
@export var jumpBufferTime := 0.25
@export var coyoteTime := 0.2

var _moveInput : float
var _jumpBufferTimer : float
var _coyoteTimer : float

@onready var jetpack: Sprite2D = $JetpackAsset

func _ready() -> void:
	CheckpointEventBus.move_player_position.connect(warp_player_to_position)
	ItemCollectionTooling.item_collected.connect(handle_item_aquisition)
	jetpack.jetpack_updated.connect(do_jetpack_logic)
	disable_item(jetpack)

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

func _process(delta: float) -> void:
	handle_inputs()
	#animation code would go here eventually

func jump() -> void:
	velocity.y = -jumpForce
	_jumpBufferTimer = 0
	_coyoteTimer = 0

func set_jump_input() -> void:
	_jumpBufferTimer = jumpBufferTime

func handle_inputs() -> void:
	_moveInput = Input.get_axis("Left", "Right")
	if Input.is_action_just_pressed("Jump"):
		set_jump_input()

func warp_player_to_position(new_position: Vector2):
	global_position = new_position

func do_jetpack_logic(speed: float):
	velocity.y -= speed;

func disable_item(item_node: Node):
	item_node.process_mode = Node.PROCESS_MODE_DISABLED
	if item_node is CanvasItem:
		item_node.hide()

func enable_item(item_node: Node):
	item_node.process_mode = Node.PROCESS_MODE_INHERIT
	if item_node is CanvasItem:
		item_node.show()

func handle_item_aquisition(item_name: String):
	var item = jetpack if item_name == "Jetpack" else null
	enable_item(item)
	pass
