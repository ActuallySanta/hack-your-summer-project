extends CharacterBody2D

@export var SPEED = 300.0
@export var JUMP_VELOCITY = -400.0

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
