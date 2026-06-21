extends CharacterBody2D

@export var SPEED = 300.0
@export var JUMP_VELOCITY = -400.0

func _ready() -> void:
	CheckpointEventBus.move_player_position.connect(warp_player_to_position)
	pass # Replace with function body.

func warp_player_to_position(new_position: Vector2):
	global_position = new_position

func _physics_process(delta: float) -> void:
	# 1. Add gravity if the character is in the air
	if not is_on_floor():
		velocity += get_gravity() * delta

	# 2. Handle Jump input (default "ui_accept" maps to Spacebar)
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# 3. Get horizontal input direction (-1 for left, 1 for right)
	var direction := Input.get_axis("Left", "Right")
	
	# 4. Apply movement or decelerate
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# 5. Execute engine physics movement
	move_and_slide()
